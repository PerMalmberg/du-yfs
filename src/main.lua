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

local step = 1

input:Register(keys.speedup, Criteria():OnRepeat(), function()
    step = step + 5
    log:Info("Step ", step)
end)

input:Register(keys.speeddown, Criteria():OnRepeat(), function()
    step = step - 0.1
    log:Info("Step ", step)
end)

function move(reference, distance)
    fc:ClearWP()
    local target = construct.position.Current() + reference * distance
    fc:AddWaypoint(Waypoint(target, calc.Kph2Mps(50), 0.1, alignment.RollTopsideAwayFromNearestBody, alignment.YawPitchKeepOrthogonalToGravity))
    fc:StartFlight()
end

input:Register(keys.forward, Criteria():OnRepeat(), function()
    move(construct.orientation.Forward(), step)
end)

input:Register(keys.backward, Criteria():OnRepeat(), function()
    move(construct.orientation.Forward(), -step)
end)

input:Register(keys.strafeleft, Criteria():OnRepeat(), function()
    move(-construct.orientation.Right(), -step)
end)

input:Register(keys.straferight, Criteria():OnRepeat(), function()
    move(construct.orientation.Right(), step)
end)

input:Register(keys.up, Criteria():OnRepeat(), function()
    move(construct.orientation.Up(), step)
end)

input:Register(keys.down, Criteria():OnRepeat(), function()
    move(construct.orientation.Up(), -step)
end)

input:Register(keys.yawleft, Criteria():OnRepeat(), function()
    fc:RotateWaypoints(1, construct.orientation.Up())
end)

input:Register(keys.yawright, Criteria():OnRepeat(), function()
    fc:RotateWaypoints(-1, construct.orientation.Up())
end)

input:Register(keys.brake, Criteria():OnPress(), function()
    brakes:Forced(true)
end)

input:Register(keys.brake, Criteria():OnRelease(), function()
    brakes:Forced(false)
end)

local start = construct.position.Current()

input:Register(keys.option8, Criteria():OnPress(), function()
    fc:ClearWP()
    fc:AddWaypoint(Waypoint(start - construct.world.GAlongGravity():normalize() * 200000, calc.Kph2Mps(1500), 0.1, alignment.RollTopsideAwayFromNearestBody, alignment.YawPitchKeepOrthogonalToGravity))
    fc:StartFlight()
end)

input:Register(keys.option9, Criteria():OnPress(), function()
    fc:ClearWP()
    fc:AddWaypoint(Waypoint(start, calc.Kph2Mps(1500), 0.1, alignment.RollTopsideAwayFromNearestBody, alignment.YawPitchKeepOrthogonalToGravity))
    fc:StartFlight()
end)