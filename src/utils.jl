macro assert_type(actual, expected_type)
    :(@assert ($(esc(actual)) isa $(esc(expected_type))) "Expected value of type $($(esc(expected_type))), got value of type $(typeof($(esc(actual)))) instead")
end
