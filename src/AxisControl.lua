local construct = require("abstraction/Construct")()
local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local calc = require("Calc")
local sharedPanel = require("panel/SharedPanel")()
local EngineGroup = require("EngineGroup")
local constants = require("Constants")
local vec3 = require("builtin/cpml/vec3")

local abs = math.abs
local max = math.max
local deg = math.deg

local rad2deg = math.pi * 180

local control = {}
control.__index = control

AxisControlPitch = 1
AxisControlRoll = 2
AxisControlYaw = 3

local finalAcceleration = {}
finalAcceleration[AxisControlPitch] = vec3()
finalAcceleration[AxisControlRoll] = vec3()
finalAcceleration[AxisControlYaw] = vec3()

---Creates a new AxisControl
---@param maxAngluarVelocity number Max angular velocity in radians/s2
---@return table A new AxisControl
local function new(maxAngluarVelocity, axis)
    diag:AssertIsNumber(maxAngluarVelocity, "maxAcceleration in AxisControl constructor must be a number")
    diag:AssertIsNumber(axis, "axis in AxisControl constructor must be a number")

    local instance = {
        controlledAxis = axis,
        maxVel = maxAngluarVelocity,
        ctrl = library.GetController(),
        targetCoordinate = nil,
        Forward = nil,
        Right = nil,
        flushHandlerId = nil,
        updateHandlerId = nil,
        offsetWidget = nil,
        velocityWidget = nil,
        accelerationWidget = nil,
        operationWidget = nil,
        operationText = "",
        torqueGroup = EngineGroup("torque"),
        maxMeasuredAcceleration = 1 -- start value, degrees per second
    }

    local shared = sharedPanel:Get("AxisControl")
    local o = construct.orientation

    if axis == AxisControlPitch then
        instance.offsetWidget = shared:CreateValue("Pitch", "°")
        instance.velocityWidget = shared:CreateValue("P.Vel", "°/s")
        instance.accelerationWidget = shared:CreateValue("P.Acc", "°/s2")
        instance.operationWidget = shared:CreateValue("P.Op", "")
        instance.Forward = o.Forward
        instance.Right = o.Up
        instance.RotationAxis = o.Right
    elseif axis == AxisControlRoll then
        instance.offsetWidget = shared:CreateValue("Roll", "°")
        instance.velocityWidget = shared:CreateValue("R.Vel", "°/s")
        instance.accelerationWidget = shared:CreateValue("R.Acc", "°/s2")
        instance.operationWidget = shared:CreateValue("R.Op", "")
        instance.Forward = o.Up
        instance.Right = o.Right
        instance.RotationAxis = o.Forward
    elseif axis == AxisControlYaw then
        instance.offsetWidget = shared:CreateValue("Yaw", "°")
        instance.velocityWidget = shared:CreateValue("Y.Vel", "°/s")
        instance.accelerationWidget = shared:CreateValue("Y.Acc", "°/s2")
        instance.operationWidget = shared:CreateValue("Y.Op", "")
        instance.Forward = o.Forward
        instance.Right = o.Right
        instance.RotationAxis = o.Up
    else
        diag:Fail("Invalid axis: " .. axis)
    end

    setmetatable(instance, control)

    return instance
end

function control:ReceiveEvents()
    self.flushHandlerId = system:onEvent("flush", self.Flush, self)
    self.updateHandlerId = system:onEvent("update", self.Update, self)
end

function control:StopEvents()
    system:clearEvent("flush", self.flushHandlerId)
    system:clearEvent("update", self.updateHandlerId)
end

function control:SetTarget(targetCoordinate)
    self.targetCoordinate = targetCoordinate
end

---Returns the current signed angular velocity, in degrees per seconds.
---@return number
function control:CurrentAngluarVelocity()
    local vel = construct.velocity.Angular() * self.RotationAxis()

    if self.controlledAxis == AxisControlPitch then
        return vel.x * rad2deg
    elseif self.controlledAxis == AxisControlRoll then
        return vel.y * rad2deg
    else
        return vel.z * rad2deg
    end
end

function control:CurrentAngularAcceleration()
    local vel = construct.acceleration.Angular() * self.RotationAxis()

    if self.controlledAxis == AxisControlPitch then
        return vel.x * rad2deg
    elseif self.controlledAxis == AxisControlRoll then
        return vel.y * rad2deg
    else
        return vel.z * rad2deg
    end
end

function control:MeasureMaxAcceleration()
    local acc = deg((construct.acceleration.Angular() * self.RotationAxis()):len())
    self.maxMeasuredAcceleration = max(self.maxMeasuredAcceleration, abs(acc))
end

function control:Flush()
    --self:MeasureMaxAcceleration()

    if self.targetCoordinate ~= nil then
        -- To turn towards the target, we want to apply an accelecation with the same sign as the offset.
        local offset = calc.AlignmentOffset(construct.position.Current(), self.targetCoordinate, self.Forward(), self.Right())
        self.offsetWidget:Set(offset * 180)
        local direction = calc.Sign(offset)

        -- Positive offset means we're right of target, clock-wise
        -- Postive acceleration turns counter-clockwise

        if self.controlledAxis == AxisControlYaw and self:CurrentAngluarVelocity() < 7 then
            finalAcceleration[self.controlledAxis] = self.RotationAxis() * math.rad(1)
            self.operationWidget:Set("Acc" .. tostring(construct.world.AngularAirFrictionAcceleration()))
        else
            self.operationWidget:Set("Wait" .. tostring(construct.world.AngularAirFrictionAcceleration()))
        end

        self:Apply()
    end
end

function control:Apply()
    local acc = finalAcceleration[AxisControlPitch] + finalAcceleration[AxisControlRoll] + finalAcceleration[AxisControlYaw]
    self.ctrl.setEngineCommand(self.torqueGroup:Union(), {0, 0, 0}, {acc:unpack()})
end

function control:Update()
    self.velocityWidget:Set(self:CurrentAngluarVelocity())
    self.accelerationWidget:Set(self:CurrentAngularAcceleration())
end

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
