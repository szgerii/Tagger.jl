export tag_match

function tag_match(::Type{T}, val::V)::Union{Type{<:T},Nothing} where {T<:TagType,V}
    @assert T != TagType "Trying to match to the base TagType type"
    @assert isabstracttype(T) "Trying to match to concrete tag instead of an abstract TagType"

    if val isa Expr
        Base.remove_linenums!(val)
    end

    result = pre_rule_match(T, val)
    if !isnothing(result)
        return result
    end

    result = tag_match_eq(T, val)
    if !isnothing(result)
        return result
    end

    result = post_rule_match(T, val)
    if !isnothing(result)
        return result
    end

    get_default_tag(T)
end

function tag_match_eq(::Type{T}, val::V)::Union{Type{<:T},Nothing} where {T<:TagType,V}
    eq_proj = get_eq_projection(T, V)
    eqval = eq_proj(val)

    eq_match(T, Val{eqval})
end
