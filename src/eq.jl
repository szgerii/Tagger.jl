export @def_eqs

#! format: off
public get_eq_projection
#! format: on

# create methods for these with the derived tag types to override behavior
get_eq_projection(::Type{T}, ::Type{V}) where {T<:TagType,V} = identity
get_eq_projection(::Type{T}, ::Type{Expr}) where {T<:TagType} = (ex::Expr) -> ex.head

eq_match(::Type{T}, ::Type{V}) where {T,V} = error("Couldn't find eq_match method for given {T, V} pair: {$T, $V}. Make sure the tag type being matched was properly declared with @def_tagtype, or you manually declared a fallback eq_match method.")

"""
	@def_eqs(T, eq_rules...)

Define the equality rules for tag type `T` through a list of (Symbol, Tag) tuples

# Arguments
- `T::Symbol`: a symbol for the tag type for which the equality rules will be defined (T <: TagType)
- `eq_rules::Vararg{Expr}`: a list of expressions representing Tuple{Symbol, ::Type{S}} pairs which represent (val == Symbol) => S rules for tag matching (S <: T)

# Examples
```jldoctest
julia> MyTagType <: TagType && TagA <: MyTagType && TagB <: MyTagType
true
julia> @def_eqs MyTagType (:some_sym, TagA) (:some_other_sym, TagB)
```
"""
macro def_eqs(T::Symbol, eq_rules::Vararg{Expr})
    fn_defs = Expr[]

    for rule in eq_rules
        Base.remove_linenums!(rule)

        @assert rule.head == :tuple "Expected Tuple, got $(rule.head) instead"
        @assert length(rule.args) == 2 "Expected 2-element tuple, got $(length(rule.args))-element tuple instead"

        eq_qn = rule.args[1]
        @assert_type eq_qn QuoteNode

        eq_val = eq_qn.value
        @assert_type eq_val Symbol

        result_sym = rule.args[2]
        @assert_type result_sym Symbol

        push!(fn_defs, :(Tagger.eq_match(::Type{$T}, ::Type{Val{$(QuoteNode(eq_val))}}) = $result_sym))
    end

    esc(Expr(:block, fn_defs...))
end
