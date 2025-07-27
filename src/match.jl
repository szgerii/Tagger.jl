export tag_match

"""
    tag_match(::Type{T}, val)

"""
function tag_match(::Type{T}, val::V)::Union{Type{<:T},Nothing} where {T<:TagType,V}
    @assert T != TagType "Trying to match to the base TagType type"
    @assert isabstracttype(T) "Trying to match to concrete tag instead of an abstract TagType"

    if val isa Expr
        Base.remove_linenums!(val)
    end

    # PRE-RULES

    result = pre_rule_match(T, val)
    if !isnothing(result)
        return result
    end

    # EQUALITY COMPARISONS

    eq_proj = get_eq_projection(T, V)
    eqval = eq_proj(val)

    result = eq_match(T, Val{eqval})
    if !isnothing(result)
        return result
    end

    # POST-RULES

    result = post_rule_match(T, val)
    if !isnothing(result)
        return result
    end

    get_default_tag(T)
end
