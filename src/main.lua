local FlightCore = require("FlightCore")
local universe = require("universe/Universe")()

local fc = FlightCore()

local testPos = universe:ParsePosition("::pos{0,2,7.6926,78.1056,40}")

fc:ReceiveEvents()
fc:EnableStabilization()
fc:EnableHoldPosition(testPos.Coords, 1)
