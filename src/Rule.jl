struct Rule{In,T,S}
    predicate::Function

    function Rule{In,T,S}(predicate::Function) where {In,T<:TagType,S<:T}
        # type assertions
        @assert T != TagType "Cannot use TagGroup as a TagType directly, an intermediate abstract class derived from TagGroup needs to be created"
        @assert isabstracttype(T) "TagType needs to be an abstract type"
        # this also implies T != S (which is a requirement too)
        @assert !isabstracttype(S) "TagResult cannot be an abstract type"

        # predicate signature assertion for extra safety
        # NOTE: this can be removed if a situation comes up where return_types doesn't give a good enough match
        @assert collect(Set(Base.return_types(predicate, (In,)))) == [Bool] "The predicate function's signature needs to be T -> Bool"

        new{In,T,S}(predicate)
    end
end
