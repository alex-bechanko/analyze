
-- analyze_assert takes a comparison function and uses the values provided to drive
-- whether the values pass the comparison function's test.
-- When using this function it's very important to 
local function analyze_assert(calling_func, expected, actual, comparison_func)
    if comparison_func(expected, actual) then
        return
    end

    error({line=calling_func.currentline})
end

-- assert_is_true
local function assert_is_true(value)
    return analyze_assert(debug.getinfo(2), nil, value, function(_, v) return v == true end)
end

-- assert_is_false
local function assert_is_false(value)
    return analyze_assert(debug.getinfo(2), nil, value, function(_, v) return v == false end)
end

-- assert_equal
local function assert_equal(expected, actual)
    return analyze_assert(debug.getinfo(2), expected, actual, function(exp, val) return exp == val end)
end


local module = {}
module.is_true = assert_is_true
module.is_false = assert_is_false
module.equal = assert_equal

-- keep reference to lua's assert just in case
module.assert = assert

return module