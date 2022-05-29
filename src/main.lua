local FlightCore = require("FlightCore")
local universe = require("universe/Universe")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")
local moveControl = require("movement/MoveControl")()
local Waypoint = require("movement/Waypoint")
local library = require("abstraction/Library")()
local brakes = require("Brakes")()

local fc = FlightCore()

--local testPos = universe:ParsePosition("::pos{0,2,7.6926,78.1056,60}")
local brakelight = library.GetLinkByName("brakelight")

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
        --moveControl:AddWaypoint(Waypoint(startPos + upDirection * 150, calc.Kph2Mps(200), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        moveControl:AddWaypoint(Waypoint(startPos + upDirection * 150 + forwardDirection * 100, calc.Kph2Mps(200), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        moveControl:AddWaypoint(Waypoint(startPos + upDirection * 150 + forwardDirection * 110, calc.Kph2Mps(5), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        moveControl:AddWaypoint(
            Waypoint(startPos + upDirection * 30 + forwardDirection * 100 + rightDirection * 30, calc.Kph2Mps(20), 0.1, RollTopsideAwayFromGravity, KeepHorizontal)
        )
        moveControl:AddWaypoint(Waypoint(startPos + upDirection * 4, calc.Kph2Mps(50), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        moveControl:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(5), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
    elseif key == "option2" then
        moveControl:Clear()
        moveControl:AddWaypoint(Waypoint(startPos + upDirection * 50, calc.Kph2Mps(300), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        moveControl:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(5), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
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

function Update(system)
    if brakes:IsEngaged() then
        brakelight.activate()
    else
        brakelight.deactivate()
    end
end

system:onEvent("actionStart", ActionStart)
system:onEvent("actionLoop", ActionLoop)
system:onEvent("actionStop", ActionStop)
system:onEvent("update", Update)
