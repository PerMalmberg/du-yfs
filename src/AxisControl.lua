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
local deg2rad = math.pi / 180

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
        maxMeasuredAcceleration = 360 -- start value, degrees per second
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

---Measures the maximum acceleration we've achieved, in deg/s2
function control:MeasureMaxAcceleration()
    local acc = (construct.acceleration.Angular() * self.RotationAxis()):len() * rad2deg
    self.maxMeasuredAcceleration = max(self.maxMeasuredAcceleration, abs(acc))
    system.print(self.maxMeasuredAcceleration)
end

function control:Flush()
    --self:MeasureMaxAcceleration()

    if self.targetCoordinate ~= nil then
        -- To turn towards the target, we want to apply an accelecation with the same sign as the offset.
        local offset = calc.AlignmentOffset(construct.position.Current(), self.targetCoordinate, self.Forward(), self.Right())
        local offsetDegrees = offset * 180
        self.offsetWidget:Set(offsetDegrees)

        -- Positive offset means we're right of target, clock-wise
        -- Postive acceleration turns counter-clockwise
        -- Positive velocity means we're turning counter-clockwise

        local angVel = self:CurrentAngluarVelocity()
        local velSign = calc.Sign(angVel)
        local isLeft = offset < 0
        local isRight = offset > 0
        local movingLeft = velSign == 1
        local movingRight = velSign == -1
        local isStandStillOutOfAlignment = (velSign == 0) and (isLeft or isRight)

        local direction
        if isLeft then
            direction = -1
        elseif isRight then
            direction = 1
        else
            direction = 0
        end

        local acceleration = 0

        if (isLeft and movingLeft) or (isRight and movingRight) then
            -- Moving away from target, need to brake, so add current velocity to our acceleration
            acceleration = self.maxMeasuredAcceleration + angVel
            self.operationWidget:Set("Away" .. acceleration)
        elseif isStandStillOutOfAlignment or (isLeft and movingRight) or (isRight and movingLeft) then
            -- Standing still, or moving towards target, reduce as we get closer
            acceleration = self.maxMeasuredAcceleration * abs(max(offset, 0.1))
            self.operationWidget:Set("Towards" .. acceleration)
        end

        if self.controlledAxis == AxisControlYaw then
            self:SetAcceleration(acceleration * direction)
        end

        self:Apply()
    end
end

function control:SetAcceleration(degreesPerS2)
    finalAcceleration[self.controlledAxis] = self:RotationAxis() * degreesPerS2 * deg2rad
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
