local construct = require("abstraction/Construct")()
local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local calc = require("Calc")
local sharedPanel = require("panel/SharedPanel")()
local EngineGroup = require("EngineGroup")
local constants = require("Constants")
local vec3 = require("builtin/cpml/vec3")
local Accelerator = require("Accelerator")

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
        accelerator = Accelerator(),
        maxAcceleration = 360 / 4 -- start value, degrees per second
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
    elseif axis == AxisControlRoll then
        instance.offsetWidget = shared:CreateValue("Roll", "°")
        instance.velocityWidget = shared:CreateValue("R.Vel", "°/s")
        instance.accelerationWidget = shared:CreateValue("R.Acc", "°/s2")
        instance.operationWidget = shared:CreateValue("R.Op", "")
        instance.Forward = o.Up
        instance.Right = o.Right
        instance.RotationAxis = o.Forward
        instance.LocalizedRotationAxis = o.localized.Forward
    elseif axis == AxisControlYaw then
        instance.offsetWidget = shared:CreateValue("Yaw", "°")
        instance.velocityWidget = shared:CreateValue("Y.Vel", "°/s")
        instance.accelerationWidget = shared:CreateValue("Y.Acc", "°/s2")
        instance.operationWidget = shared:CreateValue("Y.Op", "")
        instance.Forward = o.Forward
        instance.Right = o.Right
        instance.RotationAxis = o.Up
        instance.LocalizedRotationAxis = o.localized.Up
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

function control:BrakeAngle(speed, angularDistance)
    return speed * speed / angularDistance
end

function control:Flush()
    xpcall(
        function()
            if self.targetCoordinate ~= nil then
                -- To turn towards the target, we want to apply an accelecation with the same sign as the offset.
                local offset = calc.AlignmentOffset(construct.position.Current(), self.targetCoordinate, self.Forward(), self.Right())
                local offsetDegrees = offset * 180
                local absOffsetDegrees = abs(offsetDegrees)
                self.offsetWidget:Set(offsetDegrees)

                -- Positive offset means we're right of target, clock-wise
                -- Postive acceleration turns counter-clockwise
                -- Positive velocity means we're turning counter-clockwise

                local angVel = self:Speed()
                local absVel = abs(angVel)
                local velSign = calc.Sign(angVel)
                local isLeft = offset < 0
                local isRight = offset > 0
                local movingLeft = velSign == 1
                local movingRight = velSign == -1
                local isStandStillOutOfAlignment = abs(angVel) < 0.3 and (isLeft or isRight)

                local direction

                if isLeft then
                    direction = -1
                elseif isRight then
                    direction = 1
                else
                    direction = 0
                end

                local function MovingAway()
                    return (isLeft and movingLeft) or (isRight and movingLeft)
                end

                local function MoveTowardsTarget(speed, seconds)
                    self.accelerator:AccelerateTo(self:Speed(), speed, seconds, direction)
                end

                local function TurnDegrees(degrees)
                end

                if self.controlledAxis == AxisControlYaw then
                    local s = self:Speed()
                    --[[
            if abs(s) >= 14 then
                self.accelerator:AccelerateTo(s, 0, 5, -1)
                self.operationWidget:Set("STOP")
            elseif abs(s) <= 0.1 then
                self.accelerator:AccelerateTo(s, 15, 5, -1)
                self.operationWidget:Set("START")
            end]]
                    if self.foo == nil or self.foo == false then
                        self.foo = true
                        self.accelerator:MoveDistance(s, 2 * 360, 5, -1)
                    end

                    self:SetAcceleration(self.accelerator:Feed(self:Speed()))
                end

                self:Apply()
            end
        end,
        traceback
    )
end

function control:SetAcceleration(degreesPerS2)
    finalAcceleration[self.controlledAxis] = self:RotationAxis() * degreesPerS2 * deg2rad
end

function control:Apply()
    local acc = finalAcceleration[AxisControlPitch] + finalAcceleration[AxisControlRoll] + finalAcceleration[AxisControlYaw]
    self.ctrl.setEngineCommand(self.torqueGroup:Union(), {0, 0, 0}, {acc:unpack()})
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
