local fc = require("flight/FlightCore")()
local library = require("abstraction/Library")()
local construct = require("abstraction/Construct")()
local calc = require("util/Calc")
local brakes = require("flight/Brakes")()
local Waypoint = require("flight/Waypoint")

local brakeLight = library:GetLinkByName("brakelight")

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
        fc:ClearWP()
        --fc:AddWaypoint(Waypoint(startPos + upDirection * 150, calc.Kph2Mps(200), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos + upDirection * 150 + forwardDirection * 100, calc.Kph2Mps(200), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos + upDirection * 150 + forwardDirection * 110, calc.Kph2Mps(5), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos + upDirection * 30 + forwardDirection * 100 + rightDirection * 30, calc.Kph2Mps(20), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos + upDirection * 4, calc.Kph2Mps(50), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(5), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:StartFlight()
    elseif key == "option2" then
        fc:ClearWP()
        fc:AddWaypoint(Waypoint(startPos + upDirection * 100, calc.Kph2Mps(500), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos + upDirection * 15000, calc.Kph2Mps(5000), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos + upDirection * 100, calc.Kph2Mps(5000), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(800), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:StartFlight()
    elseif key == "option3" then
        fc:ClearWP()
        fc:AddWaypoint(Waypoint(startPos + upDirection * 10 + forwardDirection * 10, calc.Kph2Mps(200), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos + upDirection * 10 + forwardDirection * 11, calc.Kph2Mps(5), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos + upDirection * 30 + forwardDirection * 10 + rightDirection * 30, calc.Kph2Mps(20), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos + upDirection * 4, calc.Kph2Mps(50), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(5), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:StartFlight()
    elseif key == "option4" then
        fc:ClearWP()
        fc:AddWaypoint(Waypoint(startPos + upDirection * 1000, calc.Kph2Mps(800), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(800), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:StartFlight()
    elseif key == "option9" then
        fc:ClearWP()
        fc:AddWaypoint(Waypoint(startPos + upDirection * 200, calc.Kph2Mps(100), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(100), 0.1, RollTopsideAwayFromGravity, KeepHorizontal))
        fc:StartFlight()
    elseif key == "brake" then
        brakes:Forced(true)
        system.print("Enabled brakes")
    end
end

function ActionStop(system, key)
    if key == "brake" then
        brakes:Forced(false)
        system.print("Disabled brakes")
    end
end

function ActionLoop(system, key)
end

function Update(system)
    if brakes:IsEngaged() then
        brakeLight.activate()
    else
        brakeLight.deactivate()
    end
end

system:onEvent("actionStart", ActionStart)
system:onEvent("actionLoop", ActionLoop)
system:onEvent("actionStop", ActionStop)
system:onEvent("update", Update)