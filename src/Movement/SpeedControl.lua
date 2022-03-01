local library = require("abstraction/Library")()
local vec3 = require("cpml/vec3")
local PID = require("cpml/pid")
local diag = require("Diagnostics")()
local construct = require("abstraction/Construct")()
local sharedPanel = require("panel/SharedPanel")()
local brakes = require("Brakes")()
local ctrl = library.GetController()
local Engine = require("abstraction/Engine")

local speedControl = {}
speedControl.__index = speedControl

SpeedControlUp = 1
SpeedControlForward = 2
SpeedControlRight = 3
local finalAcceleration = {}
local Velocity = construct.velocity.Movement

local function ControlName(axis)
    if axis == SpeedControlUp then
        return "SpdCtrl Up"
    elseif axis == SpeedControlForward then
        return "SpdCtrl Forward"
    else
        return "SpdCtrl Right"
    end
end

local function GetAxes(axis)
    if axis == SpeedControlForward then
        return construct.orientation.Forward, construct.orientation.Right, construct.orientation.Up
    elseif axis == SpeedControlRight then
        return construct.orientation.Right, function()
            return -construct.orientation.Forward()
        end, construct.orientation.Up
    else
        return construct.orientation.Up, construct.orientation.Right, function()
            return -construct.orientation.Forward()
        end
    end
end

local function new(controlledAxis)
    diag:AssertIsNumber(controlledAxis, "name", "speedControl:new")

    local name = ControlName(controlledAxis)
    local forward, right, normal = GetAxes(controlledAxis)

    local instance = {
        controlledAxis = controlledAxis,
        forward = forward,
        right = right,
        normal = normal,
        targetVelocity = vec3(), -- The target speed and direction
        pid = PID(1, 0.001, 0),
        wPid = sharedPanel:Get(name):CreateValue("Pid", ""),
        wSpeed = sharedPanel:Get(name):CreateValue("Curr speed", "m/s"),
        wTargetSpeed = sharedPanel:Get(name):CreateValue("Trg speed", "m/s"),
        wSpeedError = sharedPanel:Get(name):CreateValue("Speed Err", "m/s"),
        wAlignment = sharedPanel:Get(name):CreateValue("Alignment", "")
    }

    setmetatable(instance, speedControl)

    return instance
end

function speedControl:SetVelocity(vel)
    diag:AssertIsVec3(vel, "vel", "speedControl:SetVelocity")
    self.targetVelocity = vel
end

function speedControl:Flush(apply)
    local forward = self.forward()
    local velocity = Velocity():project_on(forward)
    local targetVelocity = self.targetVelocity:project_on(forward)
    local targetDirection = targetVelocity:normalize()

    local speedError = targetVelocity - velocity
    self.pid:inject(speedError:len())

    local v = self.pid:get()
    finalAcceleration[self.controlledAxis] = v * targetDirection

    local alignment = velocity:dot(self.forward())
    self.wAlignment:Set(alignment)
    if alignment <= 0.9 then
        -- Not aligned enough, apply brakes in the direction of the current velocity
        brakes:SetPart("SpeedControl" .. tostring(self.controlledAxis), -velocity:normalize())
    else
        brakes:SetPart("SpeedControl" .. self.controlledAxis, vec3())
    end

    if apply then
        local total = finalAcceleration[SpeedControlUp] + finalAcceleration[SpeedControlForward] + finalAcceleration[SpeedControlRight]
        total = total - construct.world.GAlongGravity()
        ctrl.setEngineCommand(ThrustEngines:Union(), {total:unpack()})
    end

    self.wPid:Set(v)
    self.wSpeed:Set(velocity:len())
    self.wTargetSpeed:Set(targetVelocity:len())
    self.wSpeedError:Set(speedError:len())
end

-- The module
return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            return new(...)
        end
    }
)
