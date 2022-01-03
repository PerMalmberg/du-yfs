local lu = require("luaunit")
local diag = require("Diagnostics")()
local vec3 = require("builtin/vec3")

Test = {}
local result = ""
system = {
    print = function(s)
        result = s
    end
}

function Test:testDebug()
    diag:Debug("Hello", "cruel", "world")
    lu.assertEquals(result, "[D] Hello: cruel world")
end

function Test:testWarning()
    diag:Warning("Hello", "cruel", "world")
    lu.assertEquals(result, "[W] Hello: cruel world")
end

function Test:testInfo()
    diag:Info("Hello", 1, 2)
    lu.assertEquals(result, "[I] Hello: 1 2")
end

function Test:testVe3()
    diag:Info("Hello", vec3(1,2,3))
    lu.assertEquals(result, "[I] Hello: vec3(1, 2, 3)")
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
