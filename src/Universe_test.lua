local lu = require("luaunit")
local Universe = require("universe/Universe")
local library = require("abstraction/Library")()
local Position = require("universe/Position")
local vec3 = require("builtin/vec3")

local core = library.getCoreUnit()

Test = {}
local u = Universe()

function Test:testUniverse()
    core.setCurrentPlanetId(2)
    lu.assertEquals(u:ClosestBody().Name, "Alioth")
    core.setCurrentPlanetId(1)
    lu.assertEquals(u:ClosestBody().Name, "Madis")
end

function Test:testPosition()
    core.setCurrentPlanetId(2)
    local p = Position(u:CurrentGalaxyId(), u:ClosestBody(), 1, 2, 3)
    local p2 = Position(u:CurrentGalaxyId(), u:ClosestBody(), 3, 4, 5)
    lu.assertEquals(p:len(), vec3(1, 2, 3):len())
    lu.assertEquals(p.Planet.Name, "Alioth")
    lu.assertEquals(p2:len(), vec3(3, 4, 5):len())
end

function Test:testParsePosition()
    local positionOnAlioth = u:ParsePosition("::pos{0,2,7.7093,78.0806,34.7991}")
    local positionNearJago = u:ParsePosition("::pos{0,0,-102232240.0000,36433324.0000,11837611.0000}")
    local positionNearTalemai = u:ParsePosition("::pos{0,0,-10126823.0000,53124664.0000,-14922930.0000}")
    local positionNearThades = u:ParsePosition("::pos{0,0,37979880.0000,17169778.0000,-2641396.2500}")

    local s = tostring(positionOnAlioth)
    lu.assertEquals(s, "foo")
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
