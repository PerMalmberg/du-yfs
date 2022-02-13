local FlightCore = require("FlightCore")
local universe = require("universe/Universe")()
local construct = require("abstraction/Construct")()

local fc = FlightCore()

local testPos = universe:ParsePosition("::pos{0,2,7.6926,78.1056,60}")
local calc = require("Calc")

local start = construct.position.Current()
local travelPath = -construct.orientation.AlongGravity()

fc:ReceiveEvents()
fc:EnableStabilization(
    function()
        local upDirection = -construct.orientation.AlongGravity()
        return calc.StraightForward(upDirection, construct.orientation.Right()) * 10 + construct.position.Current()
    end
)
fc:EnableHoldPosition(
    function()
        return start - construct.orientation.AlongGravity() * 50
    end
)
