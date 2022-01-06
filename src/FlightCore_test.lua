local lu = require("luaunit")
local FlightCore = require("FlightCore")
local EngineGroup = require("EngineGroup")
local vec3 = require("builtin/vec3")

Test = {}

local fc = FlightCore()

function Test:testAcceleration()
    local all = EngineGroup("ALL")
    fc:Flush()
end


local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
