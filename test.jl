include("src/TagMatching.jl")

using .TagMatching

@def_tagtype ASTNode

struct CallNode <: ASTNode end
struct CallNoArgNode <: ASTNode end
struct ReturnNode <: ASTNode end
struct ForNode <: ASTNode end

@def_eqs(
    ASTNode,
    (:call, CallNode),
    (:return, ReturnNode),
    (:for, ForNode)
)

@def_pre_rules ASTNode Expr (CallNoArgNode, x -> x.head == :call && length(x.args) == 1)

@def_tagtype TypeTag VoidTag
abstract type TypeTag <: TagType end

struct IntTag <: TypeTag end
struct StringTag <: TypeTag end
struct BoolTag <: TypeTag end

@def_eqs TypeTag (:int32, IntTag) (:int64, IntTag) (:string, StringTag) (:bool, BoolTag)

macro print_var(var)
    quote
        println("$(string($(QuoteNode(var)))) is: ", $(esc(var)))
    end
end

call_node = tag_match(ASTNode, :(println("asd")))
@print_var call_node
call_argless_node = tag_match(ASTNode, :(println()))
@print_var call_argless_node
for_node = tag_match(ASTNode, :(
    for i in 1:5
    end
))
@print_var for_node
return_node = tag_match(ASTNode, :(return 3))
@print_var return_node
ast_def_node = tag_match(ASTNode, :(
    while false
    end
))
@print_var ast_def_node

int32_tag = tag_match(TypeTag, :int32)
@print_var int32_tag
int64_tag = tag_match(TypeTag, :int64)
@print_var int64_tag
string_tag = tag_match(TypeTag, :string)
@print_var string_tag
bool_tag = tag_match(TypeTag, :bool)
@print_var bool_tag
void_def_tag = tag_match(TypeTag, :void)
@print_var void_def_tag
