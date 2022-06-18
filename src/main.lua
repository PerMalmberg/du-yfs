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
local alignment = require("flight/AlignmentFunctions")

local brakeLight = library:GetLinkByName("brakelight")

fc:ReceiveEvents()

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
    fc:AddWaypoint(Waypoint(target, calc.Kph2Mps(3), 0.1, alignment.RollTopsideAwayFromNearestBody, alignment.YawPitchKeepOrthogonalToGravity))
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
    fc:RotateWaypoints(1, construct.orientation.Up())
end)

input:Register(keys.yawright, Criteria():OnRepeat(), function()
    fc:RotateWaypoints(-1, construct.orientation.Up())
end)