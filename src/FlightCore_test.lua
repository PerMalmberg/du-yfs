local lu = require("luaunit")
local FlightCore = require("FlightCore")
local Core = require("abstraction/Core")
local Controller = require("abstraction/Controller")
local EngineGroup = require("EngineGroup")

Test = {}

function Test:testAcceleration()
    local fc = FlightCore(Core(), Controller())
    local all = EngineGroup("ALL")
    fc:SetAcceleration(all, FlightCore.Forward, 2)
    lu.assertEquals(2 * FlightCore.Forward, fc:GetDesiredAcceleration())
    fc:Flush()
end


local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
