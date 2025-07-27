export TagType, DefaultTag, get_eq_projection, get_default_tag

abstract type TagType end

struct DefaultTag <: TagType end

# create methods for these with the derived tag types to override behavior
get_eq_projection(::Type{T}, ::Type{V}) where {T<:TagType,V} = identity
get_eq_projection(::Type{T}, ::Type{Expr}) where {T<:TagType} = (ex::Expr) -> ex.head
get_default_tag(::Type{T}) where {T<:TagType} = DefaultTag
