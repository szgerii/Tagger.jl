export @def_eqs

# create methods for these with the derived tag types to override behavior
get_eq_projection(::Type{T}, ::Type{V}) where {T<:TagType,V} = identity
get_eq_projection(::Type{T}, ::Type{Expr}) where {T<:TagType} = (ex::Expr) -> ex.head

eq_match(::Type{T}, ::Type{V}) where {T,V} = error("Couldn't find eq_match method for given {T, V} pair: {$T, $V}. Make sure the tag type being matched was properly declared with @def_tagtype, or you manually declared a fallback eq_match method.")

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

        push!(fn_defs, :(TagMatching.eq_match(::Type{$T}, ::Type{Val{$(QuoteNode(eq_val))}}) = $result_sym))
    end

    esc(Expr(:block, fn_defs...))
end
