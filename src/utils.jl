"""
    @assert_type val T

Assertion for checking the type of a value and printing a standard error message for it

# Arguments
- `actual::Symbol`: a symbol pointing to a value whose type should be checked
- `expected_type::Symbol`: a symbol pointing to the type `actual` should be checked against

# Examples
```jldoctest
julia> a = 12
12

julia> @assert_type a Int

julia> @assert_type a String
ERROR: AssertionError: Expected value of type String, got value of type Int64 instead
"""
macro assert_type(actual, expected_type)
    :(@assert ($(esc(actual)) isa $(esc(expected_type))) "Expected value of type $($(esc(expected_type))), got value of type $(typeof($(esc(actual)))) instead")
end
