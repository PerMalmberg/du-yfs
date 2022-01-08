local FlightCore = require("FlightCore")
local EngineGroup = require("EngineGroup")
local universe = require("universe/Universe")()
local library = require("abstraction/Library")()

local fc = FlightCore()

local testPos = universe:ParsePosition("::pos{0,2,7.6926,78.1056,50.6306}")

fc:ReceiveEvents()
fc:EnableStabilization()
fc:EnableHoldPosition(testPos.Coords, 0.1)
