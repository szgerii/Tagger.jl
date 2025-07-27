struct Rule{T,U,V}
    predicate::Function

    function Rule{T,TagType,TagResult}(predicate::Function) where {T,TagType<:TagGroup,TagResult<:TagType}
        # type assertions
        @assert TagType != TagGroup "Cannot use TagGroup as a TagType directly, an intermediate abstract class derived from TagGroup needs to be created"
        @assert isabstracttype(TagType) "TagType needs to be an abstract type"
        # this also implies TagResult != TagType (which is a requirement too)
        @assert !isabstracttype(TagResult) "TagResult cannot be an abstract type"

        # predicate signature assertion for extra safety
        # NOTE: this can be removed if a situation comes up where return_types doesn't give a good enough match
        @assert collect(Set(Base.return_types(predicate, (T,)))) == [Bool] "The predicate function's signature needs to be T -> Bool"

        new{T,TagType,TagResult}(predicate)
    end
end
