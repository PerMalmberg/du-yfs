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

local function new(controlledAxis)
    diag:AssertIsNumber(controlledAxis, "controlledAxis", "speedControl:new")

    local instance = {
        controlledAxis = controlledAxis, -- Getter for the normal vector of the plane this instance is working on.
        targetVelocity = vec3(), -- The target speed and direction
        pid = PID(0.001, 0.01, 1),
        wPid = sharedPanel:Get(ControlName(controlledAxis)):CreateValue("Pid", ""),
        wSpeed = sharedPanel:Get(ControlName(controlledAxis)):CreateValue("Curr speed", "m/s"),
        wTargetSpeed = sharedPanel:Get(ControlName(controlledAxis)):CreateValue("Trg speed", "m/s"),
        wSpeedError = sharedPanel:Get(ControlName(controlledAxis)):CreateValue("Speed Err", "m/s"),
        wAlignment = sharedPanel:Get(ControlName(controlledAxis)):CreateValue("Alignment", "")
    }

    setmetatable(instance, speedControl)

    return instance
end

function speedControl:SetVelocity(vel)
    diag:AssertIsVec3(vel, "vel", "speedControl:SetVelocity")
    self.targetVelocity = vel
end

function speedControl:NormalAxis()
    if self.controlledAxis == SpeedControlUp then
        return construct.orientation.Up()
    elseif self.controlledAxis == SpeedControlForward then
        return construct.orientation.Forward()
    else
        return construct.orientation.Right()
    end
end

function speedControl:Flush(apply)
    local normal = self:NormalAxis()
    local velocity = Velocity()
    local velocityOnPlane = velocity:project_on_plane(normal)
    local targetVelocityOnPlane = self.targetVelocity:project_on_plane(normal)
    local targetDirectionOnPlane = targetVelocityOnPlane:normalize()

    local speedError = targetVelocityOnPlane - velocityOnPlane
    self.pid:inject(speedError:len())

    local v = self.pid:get()
    finalAcceleration[self.controlledAxis] = v * targetDirectionOnPlane

    local alignment = velocity:dot(normal)
    self.wAlignment:Set(alignment)
    if alignment <= 0.9 then
        -- Not aligned enough, apply brakes in the direction of the current velocity
        brakes:SetPart("SpeedControl" .. tostring(self.controlledAxis), -velocityOnPlane:normalize())
    else
        brakes:SetPart("SpeedControl" .. self.controlledAxis, vec3())
    end

    if apply then
        local total = finalAcceleration[SpeedControlUp] + finalAcceleration[SpeedControlForward] + finalAcceleration[SpeedControlRight]
        total = total - construct.world.GAlongGravity()
        ctrl.setEngineCommand(ThrustEngines:Union(), {total:unpack()})
    end

    self.wPid:Set(v)
    self.wSpeed:Set(velocityOnPlane:len())
    self.wTargetSpeed:Set(targetVelocityOnPlane:len())
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
