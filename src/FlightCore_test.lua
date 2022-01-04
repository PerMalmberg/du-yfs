local lu = require("luaunit")
local FlightCore = require("FlightCore")
local Core = require("mock/Core")
local Controller = require("mock/Controller")
local EngineGroup = require("EngineGroup")
local vec3 = require("builtin/vec3")

Test = {}

function Test:testAcceleration()
    local fc = FlightCore()
    local all = EngineGroup("ALL")
    fc:SetAcceleration(all, vec3(0.5, 0.5, 0.5), 2)
    lu.assertEquals(2 * vec3(0.5, 0.5, 0.5), fc:GetDesiredAcceleration())
    fc:Flush()
end


local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
