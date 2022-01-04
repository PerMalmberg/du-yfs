local lu = require("luaunit")
local Universe = require("Universe")
local library = require("abstraction/Library")()

local core = library.getCoreUnit()

Test = {}

function Test:testUniverse()
    local u = Universe()
    lu.assertEquals(u:ClosestBody().Name, "Alioth")
    core.setCurrentPlanetId(2)
    lu.assertEquals(u:ClosestBody().Name, "Madis")
end


local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
