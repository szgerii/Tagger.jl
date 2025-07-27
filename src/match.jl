export tag_match

function tag_match(::Type{T}, val::V) where {T<:TagType,V}
    @assert T != TagType "Trying to match to the base TagType type"
    @assert isabstracttype(T) "Trying to match to concrete tag instead of an abstract TagType"

    # equality comparison stage
    eq_proj = Main.get_eq_projection(T, V)
    eqval = eq_proj(val)

    # TODO
    result = Main.eq_match(T, Val{eqval})

    if !isnothing(result)
        return result
    end

    get_default_tag(T)
end
