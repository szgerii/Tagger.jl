# Tagger.jl

A simple package for resolving values to tag types, which can then be used for Julia's robust multiple dispatch system.

The main aim of the project is to give a reusable framework for AST transformations and code generation, but it can be used in more general situations as well (although some limitations apply for now).

## Example usage

A minimal working example of the package can be examined in the following snippet:

```julia
using Tagger

# definition of tag type
@def_tagtype ExprNode DefaultExpr

# definition of concrete tags
struct ReturnNode <: ExprNode end
struct ForNode <: ExprNode end
struct CallNodeNoArgs <: ExprNode end
struct CallNodeWithArgs <: ExprNode end

# define what value is used for the equality comparison stage through a transformation function
# NOTE: this is for demonstration purposes only. matching on the head field is the default behavior for Expr equality checks so normally it doesn't have to be specified explicitly like this
Tagger.get_eq_projection(::Type{ExprNode}, ::Type{Expr}) = (ex::Expr) -> ex.head

# set up equality rules (if an expression's head is the left-side value, it will receive right-side tag)
@def_eqs(
    ExprNode,
    (:return, ReturnNode),
    (:for, ForNode),
    (:call, CallNodeWithArgs)
)

# define a pre-rule (checked before equality comparison) to catch no arg function calls before they are resolved based on the above :call -> CallNodeWithArgs equality rule
@def_pre_rules(
    ExprNode,
    Expr,
    (CallNodeNoArgs, (ex::Expr) -> ex.head == :call && length(ex.args) == 1)
)

# define transformation methods for specific tags

transform(expr::Expr, ::Type{ReturnNode}) = # process return expr...
transform(expr::Expr, ::Type{ForNode}) = # process for expr...
transform(expr::Expr, ::Type{CallNodeNoArgs}) = # process parameterless fn call...
transform(expr::Expr, ::Type{CallNodeWithArgs}) = # process parameterized fn call...
transform(expr::Expr, ::Type{DefaultExpr}) = println("Unsupported expression: $expr")

# now we can easily call this transform function with the help of tag_match to determine the expression's tag type, then let Julia's multiple dispatch system take care of resolving the needed method

# this will call the transform functions defined above in the order they are defined

exprs = [:(return 12), :(for i in 1:5 println(i) end), :(time()), :(println("text")), :(while true println("text") end)]

for expr in exprs
    transform(expr, tag_match(ExprNode, expr))
end
```

The surface level working of the package can be probably learnt from the above snippet, the next sections are for gaining a more advanced understanding with its concepts, flow and internals.

## Tagging System

Tag types are abstract subtypes of the base TagType abstract type, which group a set of tags together. They can be most easily defined with `@def_tagtype`. There are two parameterizations of the macro available:

```julia
@def_tagtype ExprNode
@def_tagtype ValueNode VoidValue
```

The first line defines a new tag type called ExprNode without a default tag, which will have some implications for the tag matching system later.

The second defines a ValueNode tag type with Void as the default tag.

To define tags for a tag type, simply define structs:

```julia
struct CallExpr <: ExprNode end
struct ForExpr <: ExprNode end

struct IntValue <: ValueNode end
struct StringValue <: ValueNode end
```

As these types will be defined in the surrounding module, it's a good idea to either separate them into their own `baremodule`/`module` or to give them some prefix/suffix (like `Value` and `Expr` in the above example). This also applies to tag types and default tags defined with `@def_tagtype`.

### A closer look at tag type definition

Although it's recommended to use `@def_tagtype` for defining new tag types, it can be limiting as its definitions are missed by IntelliSense in VS Code for example (this is something I want to fix later if possible). You can also define tag types manually, which in addition to being explicit towards the language server, also lets you tweak some of the default behaviors of the tag matching system.

The `@def_tagtype ExprNode DefaultTag` macro call roughly expands to the following definitions:
```julia
abstract type ExprNode <: TagType end
eq_match(::Type{ExprNode}, ::Type{Val{T}}) where T = nothing

struct DefaultTag <: ExprNode end
get_default_tag(::Type{ExprNode}) = DefaultTag
```

The last two lines are only included if the macro is called with two arguments, they are simply omitted for invocations like `@def_tagtype ExprNode`.

This sets up a couple of things:

1. Defines an ExprNode abstract type, which its tags will inherit from
1. Defines a method for `eq_match`, which is just a fallback for when no equality rules are matched for a given value. This can be potentially overriden during manual definition to (for example) short-circuit the tag matching system if there are no post-rules for the given tag.
1. Define a new tag of tag type `ExprNode` 
1. Register this new tag as the default tag for the tag type. This could also be overridden to perform some extra logic before a default tag is returned.

Keep in mind that tweaking this process during manual definition can potentially rely heavily on the internal implementation of the package, which may change in the future, so only do this carefully. Most things can be achieved without messing with this flow.

For example, performing some logging when something resolves to the default tag should be primarily done after the tag matching process has finished, instead of in the `get_default_tag` function. Most systems using this type of tag matching will support this anyways (see [Example usage](#example-usage)).

### Default-less tag types

When a tag type is defined without a default tag (either through a `@def_tagtype` invocation with a single argument, or through manual definition), the tag matching will return `nothing` when no rules are applicable instead of the default tag. There's not much difference internally otherwise, it's mainly just an ease-of-use feature for systems where you might want to have a shared no-match value between different tag types.

## Tag matching

The actual tag matching can be ran using the `tag_match` function:

```julia
tag_match(::Type{T}, val::V)::Union{Type{:< T}, Nothing} where {T <: TagType, V}
```

The signature might be a bit confusing at first, but the following example (along with [Example usage](#example-usage)) and the description below hopefully makes it clear.

### Example

```julia
@def_tagtype ExprNode DefExprNode
struct CallNode <: ExprNode end
struct WhileNode <: ExprNode end

# define some rules here

tag_match(ExprNode, :(println("text"))) # == CallNode
tag_match(ExprNode, :(while true println("spam") end)) # == WhileNode
tag_match(ExprNode, :(if i <= 0 error("index too low") end)) # == DefExprNode

@def_tagtype DefaultLessTagType

tag_match(DefaultLessTagType, :(println("i don't match any rules"))) # == nothing
```

### Flow

The tag matching system has four simple stages:

1. Pre-rules
1. Equality rules
1. Post-rules
1. Default tag

At each stage, if a concrete tag is resolved, it is immediately returned and the rest of the stages are never ran. Because of this, these should be mainly stateless rules as it is not guaranteed that the predicate fn of a rule will be called for every single match call (in fact, it most likely won't).

The following sections go through these steps, also showcasing the internal flow of the package.

### Pre-rules and post-rules

These rules are basically wrappers for predicate-tag pairs. They can either be checked before equality comparison (pre-rules) or afterwards (post-rules). The general way to define these rules is:

```julia
@def_rules(
    stage,
    T,
    V,
    (Tag, Predicate)...
)
```

where stage is either `pre` or `post`, `T <: TagType` is the tag type that the rules are being defined for, `V <: Any` is the input type that predicates will receive a value of, `Tag <: T`-s are the concrete tags that the predicate's can "nominate" for matching and `Predicate`-s are functions with signature `V -> Bool`.

For example, some simple rules for matching expressions based on their number of args can be defined like:

```julia
@def_rules(
    pre,
    ExprArgTags,
    Expr,
    (NoArgs, ex -> length(ex.args) == 0 || ex.args == [nothing])
    (EvenNumOfArgs, ex -> length(ex.args) % 2 == 0)
    (OddNumOfArgs, ex -> length(ex.args) % 2 == 1)
)
```

Shorthand macros are also provided for the two stages with `@def_pre_rules` and `@def_post_rules`. These are called in the exact same way except for the first `stage` parameter not being needed.

### Equality rules

Equality rules are checked in-between pre- and post-rules.

First, the value that is being matched is first transformed through a projection function, which is `ex -> ex.head` for `Expr`-s and simply `identity` for all other types.
This can be redefined by adding a method to `get_eq_projection` like:
```julia
Tagger.get_eq_projection(::Type{ExprNode}, ::Type{Expr}) = ex -> ex.args[1]
```

Each `(T,V)` pair (where `T` is the tag type and `V` is the value type) has exactly one projection function.

After the projection, it's then matched through a set of equality rules that can be defined like:
```julia
@def_eqs(
    ExprNode,
    (:call, CallNode),
    (:return, ReturnNode),
    (:for, ForNode)
)
```

These simply mean that whenever the matching system encounters a projected value of `:head` for example, it will automatically be resolved to a CallNode tag.

## Limitations

As the package's main focus is to provide a helper module for AST transformations and code generations, the only value types that can be matched on are `Symbol`, `Expr`, `QuoteNode`, `LineNumberNode` and any other type that can be directly passed to macros. The escaping needs to be more precise in some cases to properly support matching on arbitrary types. This is something I aim to fix in the future.

Also, all equality rules for a given tag type and predicate rules for `(T,V)` pairs must be defined within a single `@def_<...>` macro (see [Internals](#internals) for reasoning).

## Internals

The reason both predicate rules and equality rules can only be defined through macros is that they get turned into compilable code at macro expansion time that minimizes runtime lookups (and delegates the remaining to Julia's multiple dispatch system and its optimizations).

In the example codes, module specifications have been omitted, but the generated functions reside in the `Tagger` module to avoid polluting the calling scope (and let multiple modules potentially work together through this package).

### Predicate rules

Pre- and post-rules are resolved in the exact same manner, just at different times, so their implementation matches exactly. For simplicity, pre-rules will be used from here on, but you can simply replace the *pre* word with *post* to get the function names used for post-rules.

The main function which handles pre-rule matching is `pre_rule_match`. By default, this function has a generic fallback method defined like:

```julia
pre_rule_match(::Type{T}, val::Any) where T = nothing
```

This basically means that if no pre rules are defined for the given `(T,V)` pair, `nothing` will be returned as a fallback and the matching system will move on to the next stage.

`@def_rules` invocations (along with the shorthands) will generate extra methods for this function (one for each `(T,V)` pair). The body of this method will be an `if...elseif` chain of the predicates, each block simply returning its associated tag upon the condition evaluating to true. This expansion procedure is illustrated in the following snippet:

```julia
@def_pre_rules(
    ExprArgTags,
    Expr,
    (NoArgs, ex -> length(ex.args) == 0 || ex.args == [nothing])
    (EvenNumOfArgs, ex -> length(ex.args) % 2 == 0)
    (OddNumOfArgs, ex -> length(ex.args) % 2 == 1)
)

# this roughly expands to:

function pre_rule_match(::Type{ExprArgTags}, val::Expr)
    if (ex -> length(ex.args) == 0 || ex.args == [nothing])(val)
        return NoArgs
    elseif (ex -> length(ex.args) % 2 == 0)(val)
        return EvenNumOfArgs
    elseif (ex -> length(ex.args) % 2 == 1)(val)
        return OddNumOfArgs
    end

    return nothing
end
```

This happens at macro expansion time, so during matching `tag_match` simply calls `pre_rule_match(ExprArgTags, some_expr)` to get back the result of the pre-rule stage. This makes use of Julia's multiple dispatch pattern, allowing a lot of internal optimizations to happen.

### Equality rules

The equality rules work in a similar manner to predicate rules, but they also utilize the `Val` wrapper type from `Base` which lets us do dynamic dispatch on values instead of types. This imposes some limitation, as it cannot be used with complex types, so for now only `Symbol`-s are allowed (but I want to provide support for primitive types in the future).

The target function of equality rules is `eq_match`, which gets generated similarly to rule definitions (although here every equality rule gets its own method, to (again) make use of Julia's dynamic dispatch, which allows optimizations that couldn't be made with runtime Dict lookups).

The expansion looks something like:

```julia
@def_eqs(
    ExprNode,
    (:return, ReturnNode),
    (:for, ForNode),
    (:call, CallNode)
)

# this roughly expands to:

begin
    eq_match(::Type{ExprNode}, ::Type{Val{:return}}) = ReturnNode
    eq_match(::Type{ExprNode}, ::Type{Val{:for}}) = ForNode
    eq_match(::Type{ExprNode}, ::Type{Val{:call}}) = CallNode
end
```

This lets `tag_match` simply call `eq_match(T, Val{proj_val})` to get the result.

Keep in mind, that a general `eq_match` method is generated for each tag type which will return `nothing` and is called if no `Val{...}` matches the projected value. (see [A closer look at tag type definition](#a-closer-look-at-tag-type-definition)).
