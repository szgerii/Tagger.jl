using Tagger
using Test

macro tag_def_tests(name::Symbol)
    quote
        @test isdefined(@__MODULE__, $(esc(QuoteNode(name))))
        @test isabstracttype($(esc(name)))
        @test $(esc(name)) <: TagType
        @test isnothing(Tagger.eq_match($(esc(name)), Val{:some_sym}))
    end
end

@testset "Tag type definitions     " begin
    @def_tagtype TagTypeNoDef
    @tag_def_tests TagTypeNoDef
    @test isnothing(get_default_tag(TagTypeNoDef))

    @def_tagtype TagTypeWithDef DefaultTag
    @tag_def_tests TagTypeWithDef
    @test get_default_tag(TagTypeWithDef) == DefaultTag
end

@testset "Equality rules           " begin
    @def_tagtype EqTestTagType

    struct EqTagA <: EqTestTagType end
    struct EqTagB <: EqTestTagType end

    @def_eqs(
        EqTestTagType,
        (EqTagA, :some_sym),
        (EqTagB, :some_other_sym, :final_sym)
    )

    @test Tagger.eq_match(EqTestTagType, Val{:some_sym}) == EqTagA
    @test Tagger.eq_match(EqTestTagType, Val{:some_other_sym}) == EqTagB
    @test Tagger.eq_match(EqTestTagType, Val{:final_sym}) == EqTagB
    @test isnothing(Tagger.eq_match(EqTestTagType, Val{:non_existent_sym}))
end

@testset "Predicate rules          " begin
    @def_tagtype PredTestTagType

    struct SingleOrNoArg <: PredTestTagType end
    struct SameArgs <: PredTestTagType end
    struct TwoArgsTag <: PredTestTagType end

    @def_rules(
        pre,
        PredTestTagType,
        Expr,
        (SingleOrNoArg, ex -> length(ex.args) <= 1),
        (SameArgs, ex -> length(Set(ex.args)) == 1)
    )

    @def_rules(
        post,
        PredTestTagType,
        Expr,
        (TwoArgsTag, ex -> length(ex.args) == 2)
    )

    @test Tagger.pre_rule_match(PredTestTagType, Expr(:some_head)) == SingleOrNoArg
    @test Tagger.pre_rule_match(PredTestTagType, Expr(:some_head, :some_arg)) == SingleOrNoArg
    @test Tagger.pre_rule_match(PredTestTagType, Expr(:some_head, :some_arg, :some_arg, :some_arg)) == SameArgs
    @test isnothing(Tagger.pre_rule_match(PredTestTagType, Expr(:some_head, :some_arg, :different_arg)))

    @test Tagger.post_rule_match(PredTestTagType, Expr(:some_head, :some_arg, :different_arg)) == TwoArgsTag
    @test isnothing(Tagger.post_rule_match(PredTestTagType, Expr(:some_head, :some_arg, :different_arg, :third_arg)))
end

@testset "Predicate rule shorthands" begin
    @def_tagtype ShorthandTestTagType

    struct PreTag <: ShorthandTestTagType end
    struct PostTag <: ShorthandTestTagType end

    @def_pre_rules(
        ShorthandTestTagType,
        Expr,
        (PreTag, ex -> ex.head == :pre_tagged)
    )

    @def_post_rules(
        ShorthandTestTagType,
        Expr,
        (PostTag, ex -> ex.head == :post_tagged)
    )

    #@test Tagger.pre_rule_match(ShorthandTestTagType, Expr(:pre_tagged)) == PreTag
    @test isnothing(Tagger.pre_rule_match(ShorthandTestTagType, Expr(:some_sym)))

    #@test Tagger.post_rule_match(ShorthandTestTagType, Expr(:post_tagged)) == PostTag
    @test isnothing(Tagger.post_rule_match(ShorthandTestTagType, Expr(:some_sym)))
end

@testset "Tag matching             " begin
    @def_tagtype SomeTagType DefTag

    struct TagA <: SomeTagType end
    struct TagB <: SomeTagType end
    struct TagC <: SomeTagType end
    struct TagD <: SomeTagType end

    @def_eqs(
        SomeTagType,
        (TagA, :a, :aa),
        (TagB, :b, :T)
    )

    @def_rules(
        pre,
        SomeTagType,
        Expr,
        (TagA, ex -> length(ex.args) == 3 && ex.args[1] == :T),
        (TagC, ex -> length(ex.args) == 3)
    )

    @def_rules(
        post,
        SomeTagType,
        Expr,
        (TagD, ex -> string(ex.args...) == "TagD")
    )

    # test default projections
    @test Tagger.get_eq_projection(SomeTagType, Any)(:some_sym) == :some_sym
    @test Tagger.get_eq_projection(SomeTagType, Expr)(Expr(:head_sym, :arg_sym)) == :head_sym

    Tagger.get_eq_projection(::Type{SomeTagType}, ::Type{Expr}) = ex -> length(ex.args) > 0 ? ex.args[1] : :def_eq

    # eq rules
    @test tag_match(SomeTagType, Expr(:hs, :a)) == TagA
    @test tag_match(SomeTagType, Expr(:hs, :aa)) == TagA
    @test tag_match(SomeTagType, Expr(:hs, :b)) == TagB
    @test tag_match(SomeTagType, Expr(:hs, :T)) == TagB
    @test tag_match(SomeTagType, Expr(:hs, :T, :agD)) == TagB

    # pre rules
    @test tag_match(SomeTagType, Expr(:hs, :T, :ag, :D)) == TagA
    @test tag_match(SomeTagType, Expr(:hs, :Ta, :g, :D)) == TagC

    # post rules
    @test tag_match(SomeTagType, Expr(:hs, :TagD)) == TagD
    @test tag_match(SomeTagType, Expr(:hs, :Tag, :D)) == TagD

    # default
    @test tag_match(SomeTagType, Expr(:hs)) == DefTag

    @def_tagtype DeflessTagType

    @test isnothing(tag_match(DeflessTagType, Expr(:hs)))
end
