# analyze
Behavior driven development test framework to be easily used within Love2d.

This is a toy project meant for my learning how test frameworks and their internals work.

## Dependencies
This project is meant to be used within Love2d.
It relies on built-in library functions that Love2d provides.
It's possible that these can be swapped out, but that is outside the scope of my work in this project.

## Example Test

Tests are discovered/expected to be in a directory seperate from a Love2d application's source code.

```lua
local assert = require('analyze.assert')
local bdd = require('analyze.bdd')
local describe = bdd.describe
local it = bdd.it

describe("Numbers", function()
    describe("Math Operations", function()
        it("should do basic addition", function()
            assert.equal(3, 1 + 1) -- a test that fails
        end)
    end)
end)
```

## Running Tests in Lua
This is how one could hook the tests into Love2d directly.
The code below assumes that the tests were written and placed into a `test` directory at the top-level of the project.

```lua
function love.load(args)
    local bdd = require('analyze.bdd')
    ok, res = pcall(bdd.discover, "test")
    if not ok then
        print("error occurred running discovery function", res)
        love.event.quit(1)
    end
        
    ok, res = pcall(bdd.run, res)
    if not ok then
        print("error occurred running tests", res)
        love.event.quit(1)
    end
    love.event.quit(0)
end
```

The output after running the above test with this stub to run the test looks like this.

```
Numbers
  Math Operations
    FAILING - should do basic addition
      Line: 9
```