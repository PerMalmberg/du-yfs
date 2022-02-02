local FlightCore = require("FlightCore")
local universe = require("universe/Universe")()
local Panel = require("panel/Panel")

local fc = FlightCore()

local testPos = universe:ParsePosition("::pos{0,2,7.6926,78.1056,38}")
local focusPoint = universe:ParsePosition("::pos{0,2,7.6916,78.0944,40}")

fc:ReceiveEvents()
fc:EnableStabilization(focusPoint.Coords)
fc:EnableHoldPosition(testPos.Coords)
