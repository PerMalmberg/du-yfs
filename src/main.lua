local FlightCore = require("FlightCore")
local EngineGroup = require("EngineGroup")
local universe = require("universe/Universe")()
local library = require("abstraction/Library")()

local core = library.getCoreUnit()
local fc = FlightCore()

local m6 = universe:ParsePosition("::pos{0,2,36.0242,101.2872,231.3857}")


fc:ReceiveEvents()
--fc:SetAcceleration(EngineGroup("ALL"), -vec3(core.getWorldVertical()), core.g()*1.001)
fc:PointTowards(m6.Coords)
