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
local cmd = require("du-libs:commandline/CommandLine")()
local utils = require("cpml/utils")
local universe = require("du-libs:universe/Universe")()

local brakeLight = library:GetLinkByName("brakelight")

fc:ReceiveEvents()

function Update(system)
    if brakes:IsEngaged() then
        brakeLight.activate()
    else
        brakeLight.deactivate()
    end
end
system:onEvent("onUpdate", Update)

input:Register(keys.option1, Criteria():LAlt():OnPress(), function()
    if system.isFrozen() == 1 then
        system.freeze(0)
        log:Info("Automatic mode")
    else
        system.freeze(1)
        log:Info("Manual mode")
    end
end)

local step = 50
local speed = 150

local function move(reference, distance)
    fc:ClearWP()
    local target = construct.position.Current() + reference * distance
    fc:AddWaypoint(Waypoint(target, calc.Kph2Mps(speed), 0.1, alignment.RollTopsideAwayFromNearestBody, alignment.YawPitchKeepOrthogonalToGravity))
    fc:StartFlight()
end

input:Register(keys.forward, Criteria():OnRepeat(), function()
    move(construct.orientation.Forward(), step)
end)

input:Register(keys.backward, Criteria():OnRepeat(), function()
    move(construct.orientation.Forward(), -step)
end)

input:Register(keys.strafeleft, Criteria():OnRepeat(), function()
    move(-construct.orientation.Right(), step)
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
    fc:Turn(1, construct.orientation.Up())
end)

input:Register(keys.yawright, Criteria():OnRepeat(), function()
    fc:Turn(-1, construct.orientation.Up(), construct.position.Current())
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
    fc:AddWaypoint(Waypoint(start - universe:VerticalReferenceVector() * 1500, calc.Kph2Mps(1500), 0.1, alignment.RollTopsideAwayFromNearestBody, alignment.YawPitchKeepOrthogonalToGravity))
    --fc:AddWaypoint(Waypoint(start - universe:VerticalReferenceVector() * 2000, calc.Kph2Mps(1500), 0.1, alignment.RollTopsideAwayFromNearestBody, alignment.YawPitchKeepOrthogonalToGravity))
    fc:StartFlight()
end)

input:Register(keys.option9, Criteria():OnPress(), function()
    fc:ClearWP()
    --fc:AddWaypoint(Waypoint(start - universe:VerticalReferenceVector() * 200, calc.Kph2Mps(1500), 0.1, alignment.RollTopsideAwayFromNearestBody, alignment.YawPitchKeepOrthogonalToGravity))
    fc:AddWaypoint(Waypoint(start, calc.Kph2Mps(1500), 0.1, alignment.RollTopsideAwayFromNearestBody, alignment.YawPitchKeepOrthogonalToGravity))
    fc:StartFlight()
end)

local stepFunc = function(data)
    step = utils.clamp(data.commandValue, 0.1, 20000)
    log:Info("Step set to:", step)
end

cmd:Accept("step", stepFunc):AsNumber():Mandatory()

local speedFunc = function(data)
    speed = utils.clamp(data.commandValue, 1, 2000)
    log:Info("Speed set to:", speed)
end

cmd:Accept("speed", speedFunc):AsNumber():Mandatory()

local moveFunc = function(data)
    fc:ClearWP()
    local pos = construct.position.Current()
    data.v = math.abs(data.v)

    fc:AddWaypoint(Waypoint(pos + construct.orientation.Forward() * data.f + construct.orientation.Right() * data.r + construct.orientation.Up() * data.u, calc.Kph2Mps(data.v), 0.1, alignment.RollTopsideAwayFromNearestBody, alignment.YawPitchKeepOrthogonalToGravity))
    fc:StartFlight()
end

local moveCmd = cmd:Accept("move", moveFunc):AsString()
moveCmd:Option("-f"):AsNumber():Mandatory():Default(0)
moveCmd:Option("-u"):AsNumber():Mandatory():Default(0)
moveCmd:Option("-r"):AsNumber():Mandatory():Default(0)
moveCmd:Option("-v"):AsNumber():Mandatory():Default(10)

local turnFunc = function(data)
    -- Turn in the expected way, i.e. clockwise on positive values.
    local angle = -data.commandValue

    fc:Turn(angle, construct.orientation.Up(), construct.position.Current())
end

cmd:Accept("turn", turnFunc):AsNumber()

local strafeFunc = function(data)
    fc:ClearWP()
    local pos = construct.position.Current()

    local wp = Waypoint(pos + construct.orientation.Right() * data.commandValue, calc.Kph2Mps(data.v), 0.1, alignment.RollTopsideAwayFromNearestBody, alignment.YawPitchKeepWaypointDirectionOrthogonalToGravity)
    wp:OneTimeSetYawPitchDirection(construct.orientation.Forward(), alignment.YawPitchKeepWaypointDirectionOrthogonalToGravity)
    fc:AddWaypoint(wp)
    fc:StartFlight()
end

local strafeCmd = cmd:Accept("strafe", strafeFunc):AsNumber()
strafeCmd:Option("-v"):AsNumber():Mandatory():Default(10)

local axisFunc = function(data)
    fc:SetAxisMode()
end

local freeFunc = function(data)
    fc:SetFreeMode()
end

cmd:Accept("axis", axisFunc):AsEmpty()
cmd:Accept("free", freeFunc):AsEmpty()