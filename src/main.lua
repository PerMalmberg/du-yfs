local library = require("du-libs:abstraction/Library")()
local construct = require("du-libs:abstraction/Construct")()
local fc = require("flight/FlightCore")()
local calc = require("du-libs:util/Calc")
local brakes = require("flight/Brakes")()
local Waypoint = require("flight/Waypoint")
local input = require("du-libs:input/Input")()
local Criteria = require("du-libs:input/Criteria")
local keys = require("du-libs:input/Keys")
local log = require("du-libs:debug/Log")()

local brakeLight = library:GetLinkByName("brakelight")

local startPos = construct.position.Current()

fc:ReceiveEvents()

local parallelPathStart = startPos + calc.StraightForward(-construct.world.GAlongGravity(), construct.orientation.Right()) * 10 -- 10m infront

function KeepHorizontal(waypoint, previousWaypoint)
    -- Return a point at the same height 10 meters in front to keep us level
    local distanceFromStart = construct.position.Current() - startPos
    return parallelPathStart + distanceFromStart
end

function PointToNextWaypointRightAngleToToGravity(waypoint, previousWaypoint)
    local dir = (waypoint.destination - previousWaypoint.destination):normalize()
    dir = dir:project_on_plane(-construct.world.GAlongGravity():normalize_inplace())
    return construct.position.Current() + dir * 10
end

function Update(system)
    if brakes:IsEngaged() then
        brakeLight.activate()
    else
        brakeLight.deactivate()
    end
end
system:onEvent("update", Update)

input:Register(keys.option1, Criteria():LAlt():OnPress(), function()
    if system.isFrozen() == 1 then
        system.freeze(0)
        log:Info("Automatic mode")
    else
        system.freeze(1)
        log:Info("Manual mode")
    end
end)

--what happens if you clear all waypoints without adding one?
function move(reference, distance)
    fc:ClearWP()
    local target = construct.position.Current() + reference * distance
    fc:AddWaypoint(Waypoint(target, calc.Kph2Mps(3), 0.1, RollTopsideAwayFromNearestBody, PointToNextWaypointRightAngleToToGravity))
    fc:StartFlight()
end

input:Register(keys.forward, Criteria():OnPress(), function()
    move(construct.orientation.Forward(), 1)
end)

input:Register(keys.backward, Criteria():OnPress(), function()
    move(construct.orientation.Forward(), -1)
end)

input:Register(keys.strafeleft, Criteria():OnPress(), function()
    move(construct.orientation.Right(), -1)
end)

input:Register(keys.straferight, Criteria():OnPress(), function()
    move(construct.orientation.Right(), 1)
end)

input:Register(keys.up, Criteria():OnPress(), function()
    move(construct.orientation.Up(), 1)
end)

input:Register(keys.down, Criteria():OnPress(), function()
    move(construct.orientation.Up(), -1)
end)

input:Register(keys.yawleft, Criteria():OnRepeat(), function()
    fc:RotateWaypoints(0.1, construct.orientation.Up())
end)

input:Register(keys.yawright, Criteria():OnRepeat(), function()
    fc:RotateWaypoints(-0.1, construct.orientation.Up())
end)


--function ActionStart(system, key)
--    if key == "option1" then
--        fc:ClearWP()
--        --fc:AddWaypoint(Waypoint(startPos + upDirection * 150, calc.Kph2Mps(200), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 150, calc.Kph2Mps(200), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 150 + forwardDirection * 500, calc.Kph2Mps(100), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 150 + forwardDirection * 110 + rightDirection * 100, calc.Kph2Mps(100), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 300, calc.Kph2Mps(50), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(100), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:StartFlight()
--    elseif key == "option2" then
--        fc:ClearWP()
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 100, calc.Kph2Mps(500), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 15000, calc.Kph2Mps(5000), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 100, calc.Kph2Mps(5000), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(800), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:StartFlight()
--    elseif key == "option3" then
--        fc:ClearWP()
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 10 + forwardDirection * 10, calc.Kph2Mps(200), 0.1, RollTopsideAwayFromNearestBody, PointToNextWaypointRightAngleToToGravity))
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 10 + forwardDirection * 11, calc.Kph2Mps(5), 0.1, RollTopsideAwayFromNearestBody, PointToNextWaypointRightAngleToToGravity))
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 30 + forwardDirection * 10 + rightDirection * 30, calc.Kph2Mps(20), 0.1, RollTopsideAwayFromNearestBody, PointToNextWaypointRightAngleToToGravity))
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 4, calc.Kph2Mps(50), 0.1, RollTopsideAwayFromNearestBody, PointToNextWaypointRightAngleToToGravity))
--        fc:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(5), 0.1, RollTopsideAwayFromNearestBody, PointToNextWaypointRightAngleToToGravity))
--        fc:StartFlight()
--    elseif key == "option4" then
--        fc:ClearWP()
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 1000, calc.Kph2Mps(800), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(800), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:StartFlight()
--    elseif key == "option9" then
--        fc:ClearWP()
--        fc:AddWaypoint(Waypoint(startPos + upDirection * 200, calc.Kph2Mps(100), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:AddWaypoint(Waypoint(startPos, calc.Kph2Mps(100), 0.1, RollTopsideAwayFromNearestBody, KeepHorizontal))
--        fc:StartFlight()
--    elseif key == "brake" then
--        brakes:Forced(true)
--        system.print("Enabled brakes")
--    end
--end
--
--function ActionStop(system, key)
--    if key == "brake" then
--        brakes:Forced(false)
--        system.print("Disabled brakes")
--    end
--end
--
--function ActionLoop(system, key)
--end



--system:onEvent("actionStart", ActionStart)
--system:onEvent("actionLoop", ActionLoop)
--system:onEvent("actionStop", ActionStop)