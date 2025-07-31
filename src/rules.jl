export @def_rules, @def_pre_rules, @def_post_rules

pre_rule_match(::Type{T}, val) where T = nothing
post_rule_match(::Type{T}, val) where T = nothing

"""
    @def_rules stage TagType InputType rules...

Defines a new pre- or post-ruleset for a given tag type and input type.
Keep in mind, that only one ruleset can be defined per stage-tag type-input type triplet and subsequent usage will probably redefine the previous one.
The rule definition order matters, as they will be evaluated in order of definition and the tag matching system will stop after the first successful match.

# Arguments
- `stage::Symbol`: The stage to check the rules in (either `pre` or `post`)
- `T::Union{Symbol,Expr}`: The tag type to define the rules for
- `In::Union{Symbol,Expr}`: The input type to define the rules for (the type the predicates will receive as their parameter)
- `rules::Expr...`: A vararg of tuples of (Tag <: TagType, predicate::In -> Bool) pairs, which define rules with the following meaning:
    if for a given value::In, predicate(value) returns true, it will matched to Tag

# Examples
```jldoctest
julia> MyTagType <: TagType && TwoArgs <: MyTagType
true

julia> @def_rules pre MyTagType Expr (TwoArgs, (ex::Expr) -> length(ex.args) == 2)

julia> tag_match(MyTagType, Expr(:head_sym, :first_arg, :second_arg))
TwoArgs
"""
macro def_rules(stage::Symbol, T::Union{Symbol,Expr}, In::Union{Symbol,Expr}, rules::Expr...)
    @assert stage == :pre || stage == :post "Expected pre or post value for rule stage, got $stage instead"

    fn_body = []

    for rule in rules
        Base.remove_linenums!(rule)

        @assert rule.head == :tuple "Expected Tuple, got $(rule.head) instead"
        @assert length(rule.args) == 2 "Expected 2-element tuple, got $(length(rule.args))-element tuple instead"

        @assert_type rule.args[1] Symbol

        if_block = quote
            if $(esc(rule.args[2]))(val)
                return $(esc(rule.args[1]))
            end
        end

        push!(fn_body, if_block)
    end

    push!(fn_body, :(return nothing))

    fn_name = Symbol(stage, "_rule_match")

    quote
        function Tagger.$fn_name(::Type{$(esc(T))}, val::$(esc(In)))
            $(fn_body...)
        end
    end
end

"""
    @def_pre_rules TagType InputType rules...

Shorthand for calling [`@def_tagtype`](@ref) with the `pre` argument for the stage param.
"""
macro def_pre_rules(T::Symbol, In::Symbol, rules::Expr...)
    esc(quote
        @def_rules(pre, $T, $In, $(rules...))
    end)
end

"""
    @def_post_rules TagType InputType rules...

Shorthand for calling [`@def_tagtype`](@ref) with the `post` argument for the stage param.
"""
macro def_post_rules(T::Symbol, In::Symbol, rules::Expr...)
    esc(quote
        @def_rules(post, $T, $In, $(rules...))
    end)
end
