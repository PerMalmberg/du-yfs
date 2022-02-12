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

local rad2deg = 180 / math.pi
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
        Forward = nil,
        Right = nil,
        updateHandlerId = nil,
        offsetWidget = nil,
        velocityWidget = nil,
        accelerationWidget = nil,
        operationWidget = nil,
        torqueGroup = EngineGroup("torque"),
        maxAcceleration = 360 / 4, -- start value, degrees per second,
        target = {
            coordinate = nil
        },
        setAcceleration = vec3()
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
        instance.LocalizedRotationAxis = o.localized.Right
        instance.offsetDirectionChanger = -1
    elseif axis == AxisControlRoll then
        instance.offsetWidget = shared:CreateValue("Roll", "°")
        instance.velocityWidget = shared:CreateValue("R.Vel", "°/s")
        instance.accelerationWidget = shared:CreateValue("R.Acc", "°/s2")
        instance.operationWidget = shared:CreateValue("R.Op", "")
        instance.Forward = o.Up
        instance.Right = o.Right
        instance.RotationAxis = o.Forward
        instance.LocalizedRotationAxis = o.localized.Forward
        instance.offsetDirectionChanger = -1
    elseif axis == AxisControlYaw then
        instance.offsetWidget = shared:CreateValue("Yaw", "°")
        instance.velocityWidget = shared:CreateValue("Y.Vel", "°/s")
        instance.accelerationWidget = shared:CreateValue("Y.Acc", "°/s2")
        instance.operationWidget = shared:CreateValue("Y.Op", "")
        instance.Forward = o.Forward
        instance.Right = o.Right
        instance.RotationAxis = o.Up
        instance.LocalizedRotationAxis = o.localized.Up
        instance.offsetDirectionChanger = 1
    else
        diag:Fail("Invalid axis: " .. axis)
    end

    setmetatable(instance, control)

    return instance
end

function control:ReceiveEvents()
    self.updateHandlerId = system:onEvent("update", self.Update, self)
end

function control:StopEvents()
    system:clearEvent("update", self.updateHandlerId)
end

function control:SetTarget(targetCoordinate)
    self.target.coordinate = targetCoordinate
end

---Returns the current signed angular velocity, in degrees per seconds.
---@return number
function control:Speed()
    local vel = construct.velocity.localized.Angular()

    if self.controlledAxis == AxisControlPitch then
        return vel.x * rad2deg
    elseif self.controlledAxis == AxisControlRoll then
        return vel.y * rad2deg
    else
        return vel.z * rad2deg
    end
end

function control:Acceleration()
    local vel = construct.acceleration.localized.Angular()

    if self.controlledAxis == AxisControlPitch then
        return vel.x * rad2deg
    elseif self.controlledAxis == AxisControlRoll then
        return vel.y * rad2deg
    else
        return vel.z * rad2deg
    end
end

---Returns the time it takes to reach the target, in seconds
---@param offsetInDegrees number of degrees we're off alignment
---@param angleVel number Angular velocity
function control:TimeToTarget(offsetInDegrees, angleVel)
    local time
    if angleVel ~= 0 then
        time = offsetInDegrees / angleVel
    else
        time = constants.flushTick
    end

    return time
end

function control:BrakeAcceleration(speed, offsetInDegrees)
    return speed * speed / offsetInDegrees
end

function control:BrakeDistance(speed, acceleration)
    return speed * speed / acceleration
end

function control:SpeedInTicks(ticks)
    return self:Speed() + self:Acceleration() * constants.flushTick * ticks
end

function control:Flush(apply)
    if self.target.coordinate ~= nil then
        -- Positive offset means we're right of target, clock-wise
        -- Postive acceleration turns counter-clockwise
        -- Positive velocity means we're turning counter-clockwise

        local offset = calc.AlignmentOffset(construct.position.Current(), self.target.coordinate, self.Forward(), self.Right())
        local speed = self:Speed()
        local absSpeed = abs(speed)
        local speedSign = calc.Sign(speed)
        local isLeft = offset < 0
        local isRight = offset > 0
        local movingLeft = speedSign == self.offsetDirectionChanger
        local movingRight = speedSign == -self.offsetDirectionChanger
        local movingAway = (isLeft and movingLeft) or (isRight and movingRight)

        local towardsTarget = calc.Sign(offset) * self.offsetDirectionChanger

        local accelerationConstant = 50

        local absOffset = abs(offset)
        local absDegreeOffset = absOffset * 180
        local acc = 0

        self.operationWidget:Set("Offset " .. calc.Round(absDegreeOffset, 4))
        if movingAway then
            acc = 2 * accelerationConstant * towardsTarget
        elseif self:SpeedInTicks(1) < self.maxVel then
            if absDegreeOffset <= self:BrakeDistance(absSpeed, accelerationConstant) then
                acc = accelerationConstant * -calc.Sign(offset)
            else
                acc = accelerationConstant * towardsTarget
            end
        end

        finalAcceleration[self.controlledAxis] = self:RotationAxis() * acc * deg2rad
    end

    if apply then
        self:Apply()
    end
end

function control:Apply()
    self.setAcceleration = finalAcceleration[AxisControlPitch] + finalAcceleration[AxisControlRoll] + finalAcceleration[AxisControlYaw]
    self.ctrl.setEngineCommand(self.torqueGroup:Union(), {0, 0, 0}, {self.setAcceleration:unpack()})
end

function control:Update()
    self.velocityWidget:Set(self:Speed())
    self.accelerationWidget:Set(self:Acceleration())
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
