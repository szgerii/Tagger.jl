export @def_eqs

macro def_eqs(TagType::Symbol, eq_rules::Vararg{Expr})
    fn_defs = Expr[]

    # TODO dont allow any T to be inside Val, only Symbol values (maybe through @generated functions and a manual type check in the body)
    push!(fn_defs, :(eq_match(::Type{$TagType}, ::Type{Val{T}}) where T = nothing))

    for rule in eq_rules
        @assert rule.head == :tuple "Expected Tuple, got $(rule.head) instead"
        @assert length(rule.args) == 2 "Expected 2-element tuple, got $(length(rule.args))-element tuple instead"

        eq_qn = rule.args[1]
        @assert_type eq_qn QuoteNode

        eq_val = eq_qn.value
        @assert_type eq_val Symbol

        result_sym = rule.args[2]
        @assert_type result_sym Symbol

        push!(fn_defs, :(eq_match(::Type{$TagType}, ::Type{Val{$(QuoteNode(eq_val))}}) = $result_sym))
    end

    esc(Expr(:block, fn_defs...))
end
