local FlightCore = require("FlightCore")
local universe = require("universe/Universe")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")

local fc = FlightCore()

--local testPos = universe:ParsePosition("::pos{0,2,7.6926,78.1056,60}")

local startPos = construct.position.Current()
local upDirection = -construct.orientation.AlongGravity()
local parallelPathStart = startPos + calc.StraightForward(upDirection, construct.orientation.Right()) * 100 -- 100m infront

fc:ReceiveEvents()

function ActionStart(system, key)
    if key == "option1" then
    elseif key == "option2" then
    end
end

system:onEvent("actionStart", ActionStart)
