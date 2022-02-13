local inspect = require("lib.inspect")
local filesystem = {}
filesystem.getDirectoryItems = love.filesystem.getDirectoryItems
filesystem.getInfo = love.filesystem.getInfo
filesystem.load = love.filesystem.load

-- table_is_empty is a fast check for if a table is empty
local function table_is_empty(tbl)
    return next(tbl) == nil
end

-- starts_with checks if a string begins with a specified prefix.
-- Taken from http://lua-users.org/wiki/StringRecipes.
local function starts_with(str, start)
    return str:sub(1, #start) == start
 end

-- ends_with checks if a string ends with a specified suffix.
-- Taken from http://lua-users.org/wiki/StringRecipes.
local function ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

-- new_test_layer is a constructor function for a layer.
-- A layer is an abstraction used to denote the tree-like structure
-- that `describe` and `it` statements make.
local function new_test_layer(name, tag, parent)
    local lvl = {}
    lvl.depth = 0
    lvl.tag = tag
    lvl.name = name
    lvl.ok = true
    lvl.error_message = ""
    lvl.line = nil
    lvl.children = {}
    return lvl
end

local TAG_ROOT = "root"
local TAG_DESCRIBE = "describe"
local TAG_IT = "it"

local TAB = "  "
local TEST_TYPE_PASS = "pass"
local TEST_TYPE_FAIL = "fail"
local TEST_TYPE_PENDING = "pending"

local TEST_RESULT_STRINGIFY = {}
TEST_RESULT_STRINGIFY[TEST_TYPE_PASS] = "PASSING"
TEST_RESULT_STRINGIFY[TEST_TYPE_FAIL] = "FAILING"
TEST_RESULT_STRINGIFY[TEST_TYPE_PENDING] = "PENDING"

local ERROR_DESCRIBE_AFTER_IT = "Attempted to embed a `describe` call inside an `it` call."

local bdd = {}
bdd.root_layer = new_test_layer("", TAG_ROOT)
bdd.current_layer = bdd.root_layer

-- repeat_string takes a string and concatenates to itself a specified amount of times.
-- This function is mainly used for programmatically making a tabbed structure of the
-- `describe` and `it` tree
local function repeat_string(s, num)
    if num <= 0 then
        return ""
    end

    local ret = ""
    for i = 1, num do
        ret = ret .. s
    end
    return ret
end

-- print_human_message prints out a layer in a human readable format.
-- If the layer is an `it` layer then it provides PASS/FAIL/PEND and error messaging where appropriates
local function print_human_message(depth, message, tag, test_result_type, test_result)
    local tab = repeat_string(TAB, depth)
    local result_display = ""
    if tag == TAG_IT then
        result_display = string.format("%s - ",TEST_RESULT_STRINGIFY[test_result_type])
    end

    print(string.format("%s%s%s", tab, result_display, message))

    if tag == TAG_IT and test_result_type == TEST_TYPE_FAIL and test_result.message ~= nil then
        local err_tab = repeat_string(TAB, depth + 1)
        print(string.format("%sError: %s", err_tab, test_result.message))
    end

    if tag == TAG_IT and test_result_type == TEST_TYPE_FAIL and test_result.line ~= nil then
        local err_tab = repeat_string(TAB, depth + 1)
        print(string.format("%sLine: %s", err_tab, test_result.line))
    end
end

-- describe is used to group a set of tests under a shared group name.
-- This function will error if the parent group it is in is an `it` group.
-- In other words, this is intended as an internal tree node, and `it` is
-- intended for leaf nodes.
local function describe(name, tests_func)
    local previous_layer = bdd.current_layer
    if previous_layer.tag == TAG_IT then
        error({message=ERROR_DESCRIBE_AFTER_IT, line=debug.getinfo(2).currentline})
    end

    local layer = new_test_layer(name, TAG_DESCRIBE)
    if previous_layer.tag == TAG_ROOT then
        layer.depth = 0
    else
        layer.depth = previous_layer.depth + 1
    end
    table.insert(previous_layer.children, layer)

    print_human_message(layer.depth, name, TAG_DESCRIBE)

    bdd.current_layer = layer
    if tests_func ~= nil then
        local ok, err = pcall(tests_func)
        if not ok or err ~= nil then
            print_human_message(layer.depth, string.format("Failed to execute tests starting at line %d", TAG_IT, TEST_TYPE_FAIL))
        end
    end
    bdd.current_layer = previous_layer
end


-- it takes a message that describes the test, and a test function and prints out
-- whether the test function passed or not.
local function it(message, test_func)
    local previous_layer = bdd.current_layer
    local layer = new_test_layer(message, TAG_IT)
    layer.depth = previous_layer.depth + 1
    table.insert(previous_layer.children, layer)

    bdd.current_layer = layer
    local ok, err
    if test_func ~= nil then
        ok, err = pcall(test_func)
    end

    if test_func == nil then
        print_human_message(layer.depth, message, TAG_IT, TEST_TYPE_PENDING)
    elseif not ok or err ~= nil then
        print_human_message(layer.depth, message, TAG_IT, TEST_TYPE_FAIL, err)
    else
        print_human_message(layer.depth, message, TAG_IT, TEST_TYPE_PASS)
    end

    bdd.current_layer = previous_layer
end

-- load_test_file takes a path to a lua file, loads and runs the file.
-- The expectation is that the file returns a module that the testing library
-- will inspect and run test functions with.
local function load_test_file(f)
    local ok, chunk, t

    ok, chunk = pcall( filesystem.load, f )
    if not ok then
        -- chunk is the error string on a failure to load the file
        return nil, tostring(chunk)
    end

    -- load the data into memory
    ok, t = pcall(chunk)
    if not ok then 
        return nil, tostring(t)
    end

    return t
end

-- discover takes a relative path, and enumerates within that path
-- to find any lua files.
-- Any files found are considered test files and will be returned in sorted order.
local function discover(directory)
    local fs = filesystem.getDirectoryItems(directory)
    for i, f in ipairs(fs) do
        fs[i] = string.format("%s/%s", directory, f)
    end

    local testfiles = {}

    while not table_is_empty(fs) do
        local f = table.remove(fs)
        local info = filesystem.getInfo(f)

        if ends_with(f, ".lua") and info.type =="file" then
            table.insert(testfiles, f)
        elseif info.type =="directory" then
            local contents = filesystem.getDirectoryItems(f)
            for _, newfile in pairs(contents) do
                table.insert(fs, string.format("%s/%s", f, newfile))
            end
        end
    end

    table.sort(testfiles)

    return testfiles
end

-- run executes the provided lua files.
-- The files are expected to be test files which use the API defined in this file.
-- Regardless of whether they are using the API, all the files passed are executed.
local function run(test_files)
    for _, filename in ipairs(test_files) do
        load_test_file(filename)
    end
end

local module = {}
module.describe = describe
module.it = it
module.discover = discover
module.run = run

return module