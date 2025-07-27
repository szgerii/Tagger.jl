# create methods for these with the derived tag types to override behavior
get_eq_projection(::Type{T}, ::Type{V}) where {T<:TagType,V} = identity
get_eq_projection(::Type{T}, ::Type{Expr}) where {T<:TagType} = (ex::Expr) -> ex.head

get_default_tag(::Type{T}) where {T<:TagType} = nothing

eq_match(::Type{T}, ::Type{V}) where {T,V} = error("Couldn't find eq_match method for given (T,V) pair ($T,$V). Make sure the tag type being matched was properly declared with @def_tagtype, or you manually declared the fallback eq_match method.")