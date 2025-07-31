export @def_eqs

#! format: off
public get_eq_projection
#! format: on

# create methods for these with the derived tag types to override behavior

"""
    get_eq_projection(::Type{TagType}, ::Type{ValType}) where {T <: TagType, V}

Retrieves the projection function for the given tag type-value type pair.
During tag matching, this will be applied to every value of type `ValType` before it is checked for equality.
The standard behavior for all non-Expr types is to simply use the [`identity`](@ref) function.
For values of type Expr, ex -> ex.head is used for convenience.

Keep in mind, that equality checks can only be ran on types whose values are usable through the [`Val{T}`](@ref) wrapper ([`isbits`](@ref) types).

# Arguments
- `::Type{T} where {T <: TagType}`: The tag type to define the projection function for
- `::Type{V}`: The input value type to define the projection function for
"""
get_eq_projection(::Type{T}, ::Type{V}) where {T<:TagType,V} = identity
get_eq_projection(::Type{T}, ::Type{Expr}) where {T<:TagType} = (ex::Expr) -> ex.head

eq_match(::Type{T}, ::Type{V}) where {T,V} = error("Couldn't find eq_match method for given {T, V} pair: {$T, $V}. Make sure the tag type being matched was properly declared with @def_tagtype, or you manually declared a fallback eq_match method.")

"""
	@def_eqs(T, eq_rules...)

Define the equality rules for tag type `T` through a list of (Symbol, Tag) tuples.

# Arguments
- `T::Symbol`: a symbol for the tag type for which the equality rules will be defined (T <: TagType)
- `eq_rules::Vararg{Expr}`: a list of expressions representing Tuple{::Type{S}, syms::Symbol...} tuples which represent (val in syms) => S rules for tag matching (S <: T)

# Examples
```jldoctest
julia> MyTagType <: TagType && TagA <: MyTagType && TagB <: MyTagType
true
julia> @def_eqs MyTagType (TagA, :some_sym) (TagB, :this_resolves_to_tag_b, :this_resolves_to_b_too)
```
"""
macro def_eqs(T::Symbol, eq_rules::Vararg{Expr})
    fn_defs = Expr[]

    for rule in eq_rules
        Base.remove_linenums!(rule)

        @assert rule.head == :tuple "Expected Tuple, got $(rule.head) instead"
        @assert length(rule.args) >= 2 "Expected tuple of element count equal to or more than 2, got $(length(rule.args))-element tuple instead"

        result_sym = rule.args[1]
        @assert_type result_sym Symbol

        for i in 2:length(rule.args)
            eq_qn = rule.args[i]
            @assert_type eq_qn QuoteNode

            eq_val = eq_qn.value
            @assert_type eq_val Symbol

            push!(fn_defs, :(Tagger.eq_match(::Type{$T}, ::Type{Val{$(QuoteNode(eq_val))}}) = $result_sym))
        end
    end

    esc(Expr(:block, fn_defs...))
end
