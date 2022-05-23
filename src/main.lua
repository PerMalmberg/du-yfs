local FlightCore = require("FlightCore")
local universe = require("universe/Universe")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")
local moveControl = require("movement/MoveControl")()
local WayPoint = require("movement/WayPoint")

local fc = FlightCore()

--local testPos = universe:ParsePosition("::pos{0,2,7.6926,78.1056,60}")

local upDirection = -construct.orientation.AlongGravity()
local forwardDirection = construct.orientation.Forward()
local rightDirection = construct.orientation.Right()
local startPos = construct.position.Current()

fc:ReceiveEvents()

local parallelPathStart = startPos + calc.StraightForward(-construct.world.GAlongGravity(), construct.orientation.Right()) * 10 -- 10m infront

function KeepHorizontal(waypoint)
    -- Return a point at the same height 10 meters infront to keep us level
    local distanceFromStart = construct.position.Current() - startPos
    return parallelPathStart + distanceFromStart
end

function ActionStart(system, key)
    if key == "option1" then
        moveControl:Clear()
        moveControl:AddWaypoint(WayPoint(startPos + upDirection * 150, calc.Kph2Mps(20), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        moveControl:AddWaypoint(WayPoint(startPos + upDirection * 150 + forwardDirection * 200, calc.Kph2Mps(200), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        moveControl:AddWaypoint(
            WayPoint(startPos + upDirection * 30 + forwardDirection * 100 + rightDirection * 30, calc.Kph2Mps(20), 0.1, RollTopsideAwayFromGravity, KeepHorizontal)
        )
        moveControl:AddWaypoint(WayPoint(startPos + upDirection * 4, calc.Kph2Mps(15), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        moveControl:AddWaypoint(WayPoint(startPos, calc.Kph2Mps(5), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
    elseif key == "option2" then
        moveControl:Clear()
        moveControl:AddWaypoint(WayPoint(startPos + upDirection * 4, calc.Kph2Mps(15), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        moveControl:AddWaypoint(WayPoint(startPos, calc.Kph2Mps(5), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
    elseif key == "option3" then
        moveControl:Clear()
    elseif key == "option9" then
        moveControl:Clear()
    elseif key == "brake" then
        moveControl:SetBrake(true)
        system.print("Enabled brakes")
    end
end

function ActionStop(system, key)
    if key == "brake" then
        moveControl:SetBrake(false)
        system.print("Diasbled brakes")
    end
end

function ActionLoop(system, key)
end

system:onEvent("actionStart", ActionStart)
system:onEvent("actionLoop", ActionLoop)
system:onEvent("actionStop", ActionStop)
