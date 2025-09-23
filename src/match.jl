export tag_match

"""
    tag_match(::Type{T}, val::Any) where {T <: TagType} -> Union{Type{<:T}, Nothing}

Runs the tag matching process with a given value `val` for the tag type `T`.
It's important that all predicate and equality rules have already defined by this point, otherwise a [`MethodError`](@ref) will be thrown.
What the function returns if no tag matches for the value depends on whether a default tag has been registered for the tag type. See [`get_default_tag`](@ref) for details.

# Arguments
- `::Type{T <: TagType}`: The tag type to run the tag matching process for
- `val::Any`: The value to run the tag matching process with

# Examples
```jldoctest
julia> @def_tagtype MyTagType DefaultTag

julia> struct TagA <: MyTagType end ; struct TagB <: MyTagType end ; struct TagC <: MyTagType end

julia> @def_eqs MyTagType (TagA, :resolve_to_a)

julia> @def_pre_rules MyTagType Expr (TagB, ex -> length(ex.args) >= 1 && ex.args[1] == :resolve_to_b)

julia> @def_post_rules MyTagType Expr (TagC, ex -> length(ex.args) >= 1 && ex.args[1] == :resolve_to_c)

julia> tag_match(MyTagType, Expr(:resolve_to_a))
TagA

julia> tag_match(MyTagType, Expr(:resolve_to_a, :resolve_to_b))
TagB

julia> tag_match(MyTagType, Expr(:resolve_to_a, :resolve_to_c))
TagA

julia> tag_match(MyTagType, Expr(:some_sym, :resolve_to_c))
TagC

julia> tag_match(MyTagType, Expr(:some_sym))
DefaultTag
"""
function tag_match(::Type{T}, val::V)::Union{Type{<:T},Nothing} where {T<:TagType,V}
    @assert T != TagType "Trying to match to the base TagType type"
    @assert isabstracttype(T) "Trying to match to concrete tag instead of an abstract TagType"

    # PRE-RULES

    result = pre_rule_match(T, val)
    if !isnothing(result)
        return result
    end

    # EQUALITY COMPARISONS

    eq_proj = get_eq_projection(T, V)
    eqval = eq_proj(val)

    if isbits(eqval) || eqval isa Symbol
        result = eq_match(T, Val{eqval})
        if !isnothing(result)
            return result
        end
    end

    # POST-RULES

    result = post_rule_match(T, val)
    if !isnothing(result)
        return result
    end

    get_default_tag(T)
end
