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
        currentOffsetAngle = 0,
        currentAcceleration = 0,
        torqueGroup = EngineGroup("torque"),
        maxMeasuredAcceleration = 1, -- start value, degrees per second
        adjustment = {
            accelerationTimeRemaining = 0,
            targetSpeed = 0
        }
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

function control:CurrentAngluarVelocity()
    return abs(deg((construct.velocity.Angular() * self.RotationAxis()):len()))
end

function control:MeasureMaxAcceleration()
    local acc = deg((construct.acceleration.Angular() * self.RotationAxis()):len())
    self.maxMeasuredAcceleration = max(self.maxMeasuredAcceleration, abs(acc))
end

function control:TimeToTarget()
    local timeToTarget = 1
    local angVel = self:CurrentAngluarVelocity()

    if angVel ~= 0 then
        timeToTarget = self.currentOffsetAngle / angVel
    end

    return timeToTarget
end

function control:BrakeTime()
    local time = self:CurrentAngluarVelocity() / self.maxMeasuredAcceleration
    return time
end

function control:AdjustSpeed(newVelocity)
    local currVel = self:CurrentAngluarVelocity()

    -- V = V0 + a * t => t = (V - V0) / a
    self.adjustment.accelerationTimeRemaining = (newVelocity - currVel) / self.maxMeasuredAcceleration
    self.adjustment.targetSpeed = newVelocity
end

function control:Flush()
    --self:MeasureMaxAcceleration()

    if self.targetCoordinate ~= nil then
        if self.adjustment.accelerationTimeRemaining > 0 then
            self.operationText = "Adjusting"
            self.adjustment.accelerationTimeRemaining = self.adjustment.accelerationTimeRemaining - constants.flushTick

            if self:CurrentAngluarVelocity() < self.adjustment.targetSpeed then
                self.currentAcceleration = self.maxMeasuredAcceleration
            else
                self.currentAcceleration = -self.maxMeasuredAcceleration
            end

            if self.controlledAxis == AxisControlYaw then
                finalAcceleration[self.controlledAxis] = self.RotationAxis() * self.currentAcceleration
            end
        else
            self.operationText = "Control"
            local offset = calc.AlignmentOffset(construct.position.Current(), self.targetCoordinate, self.Forward(), self.Right())

            -- To turn towards the target, we want to apply an accelecation with the same sign as the offset.
            local direction = calc.Sign(self.currentOffsetAngle)

            self:AdjustSpeed(abs(offset) * self.maxVel * direction)

            self.currentOffsetAngle = offset * 180
        end

        self:Apply()
    end
end

function control:Apply()
    local acc = finalAcceleration[AxisControlPitch] + finalAcceleration[AxisControlRoll] + finalAcceleration[AxisControlYaw]
    self.ctrl.setEngineCommand(self.torqueGroup:Union(), {0, 0, 0}, {acc:unpack()})
end

function control:Update()
    self.offsetWidget:Set(self.currentOffsetAngle)
    self.velocityWidget:Set(self:CurrentAngluarVelocity())
    self.accelerationWidget:Set(self.currentAcceleration)
    self.operationWidget:Set(self.operationText)
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
