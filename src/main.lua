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
fc:EnableStabilization(
    function()
        --return construct.player.position.Current()
        local distanceFromStart = construct.position.Current() - startPos
        return parallelPathStart + upDirection * distanceFromStart:len()
    end
)
--[[fc:EnableHoldPosition(
    function()
        local camera = construct.player.camera
        return camera.position.Current() + camera.orientation.Forward() * 45
        --return start - construct.orientation.AlongGravity() * 50
    end
)]]
function ActionStart(system, key)
    if key == "option1" then
        fc:EnableHoldPosition(
            function()
                return startPos - construct.orientation.AlongGravity() * 500
            end
        )
    elseif key == "option2" then
        fc:EnableHoldPosition(
            function()
                return startPos + upDirection * 10
                --return start - construct.orientation.AlongGravity() * 50
            end
        )
    end
end

system:onEvent("actionStart", ActionStart)
