export @def_rules, @def_pre_rules, @def_post_rules

pre_rule_match(::Type{T}, val) where T = nothing
post_rule_match(::Type{T}, val) where T = nothing

macro def_rules(stage::Symbol, T::Symbol, In::Symbol, rules::Expr...)
    @assert stage == :pre || stage == :post "Expected pre or post value for rule stage, got $stage instead"

    fn_body = Expr(:block)

    for rule in rules
        Base.remove_linenums!(rule)

        @assert rule.head == :tuple "Expected Tuple, got $(rule.head) instead"
        @assert length(rule.args) == 2 "Expected 2-element tuple, got $(length(rule.args))-element tuple instead"

        @assert_type rule.args[1] Symbol

        if_block = quote
            if $(esc(rule.args[2]))(val)
                return $(esc(rule.args[1]))
            end
        end

        push!(fn_body.args, if_block)
    end

    push!(fn_body.args, :(return nothing))

    fn_name = Symbol(stage, "_rule_match")
    fn_arg1 = Expr(:(::), Expr(:curly, :Type, esc(T)))
    fn_arg2 = Expr(:(::), :val, esc(In))

    fn_def = Expr(
        :function,
        Expr(:call, fn_name, fn_arg1, fn_arg2),
        fn_body
    )

    Base.remove_linenums!(fn_def)
    esc(fn_def)
end

macro def_pre_rules(T::Symbol, In::Symbol, rules::Expr...)
    :(@def_rules pre $T $In $(rules...))
end

macro def_post_rules(T::Symbol, In::Symbol, rules::Expr...)
    :(@def_rules post $T $In $(rules...))
end
