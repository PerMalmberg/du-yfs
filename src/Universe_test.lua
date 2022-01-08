local lu = require("luaunit")
local Universe = require("universe/Universe")
local library = require("abstraction/Library")()
local Position = require("universe/Position")
local vec3 = require("builtin/cpml/vec3")

local core = library.GetCoreUnit()

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
    local p = Position(u:CurrentGalaxy(), u:ClosestBody(), 1, 2, 3)
    local p2 = Position(u:CurrentGalaxy(), u:ClosestBody(), 3, 4, 5)
    lu.assertEquals(p.Coords:len(), vec3(1, 2, 3):len())
    lu.assertEquals(p.Body.Name, "Alioth")
    lu.assertEquals(p2.Coords:len(), vec3(3, 4, 5):len())
end

function Test:testParsePosition()
    local positionOnAlioth = u:ParsePosition("::pos{0,2,7.7093,78.0806,34.7991}")
    local positionAboveMarket6 = u:ParsePosition("::pos{0,2,35.9160,101.2832,132000.2500}")
    local positionNearJago = u:ParsePosition("::pos{0,0,-102232240.0000,36433324.0000,11837611.0000}")
    local positionNearTalemai = u:ParsePosition("::pos{0,0,-10126823.0000,53124664.0000,-14922930.0000}")
    local positionNearThades = u:ParsePosition("::pos{0,0,37979880.0000,17169778.0000,-2641396.2500}")
    local positionAboveIon = u:ParsePosition("::pos{0,0,2970018.8563,-98961141.3186,-787105.8790}")
    local market6Pad = u:ParsePosition("::pos{0,2,36.0242,101.2872,231.3857}")
    local sveaBaseSWSide = u:ParsePosition("::pos{0,2,7.5425,78.0995,47.6314}")

    lu.assertEquals(tostring(positionOnAlioth), "::pos{0,2,7.7093,78.0806,34.7991}")
    lu.assertEquals(tostring(positionAboveMarket6), "::pos{0,2,35.9160,101.2832,132000.2500}")
    lu.assertEquals(tostring(positionNearJago), "::pos{0,0,-102232240.0000,36433324.0000,11837611.0000}")
    lu.assertEquals(tostring(positionNearTalemai), "::pos{0,0,-10126823.0000,53124664.0000,-14922930.0000}")
    lu.assertEquals(tostring(positionNearThades), "::pos{0,0,37979880.0000,17169778.0000,-2641396.2500}")
    lu.assertEquals(tostring(positionAboveIon), "::pos{0,0,2970018.8563,-98961141.3186,-787105.8790}")
    lu.assertEquals(tostring(market6Pad), "::pos{0,2,36.0242,101.2872,231.3857}")
    lu.assertEquals(tostring(sveaBaseSWSide), "::pos{0,2,7.5425,78.0995,47.6314}")

    lu.assertEquals((positionOnAlioth.Coords - positionOnAlioth.Coords):len(), 0)
    lu.assertEquals(math.floor((sveaBaseSWSide.Coords - market6Pad.Coords):len()), 76934)
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
