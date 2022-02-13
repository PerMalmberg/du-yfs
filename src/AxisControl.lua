local construct = require("abstraction/Construct")()
local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local calc = require("Calc")
local sharedPanel = require("panel/SharedPanel")()
local EngineGroup = require("EngineGroup")
local constants = require("Constants")
local vec3 = require("builtin/cpml/vec3")
local PID = require("builtin/cpml/PID")

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
---@return table A new AxisControl
local function new(axis)
    diag:AssertIsNumber(axis, "axis in AxisControl constructor must be a number")

    local instance = {
        controlledAxis = axis,
        ctrl = library.GetController(),
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
        setAcceleration = vec3(),
        pid = PID(24, 16, 1600, 0.5) -- 0.5 amortization makes it alot smoother
    }

    local shared = sharedPanel:Get("AxisControl")
    local o = construct.orientation

    if axis == AxisControlPitch then
        instance.offsetWidget = shared:CreateValue("Pitch", "°")
        instance.velocityWidget = shared:CreateValue("P.Vel", "°/s")
        instance.accelerationWidget = shared:CreateValue("P.Acc", "°/s2")
        instance.operationWidget = shared:CreateValue("P.Op", "")
        instance.Reference = o.Forward
        instance.Normal = o.Right
        instance.LocalNormal = construct.orientation.localized.Right
    elseif axis == AxisControlRoll then
        instance.offsetWidget = shared:CreateValue("Roll", "°")
        instance.velocityWidget = shared:CreateValue("R.Vel", "°/s")
        instance.accelerationWidget = shared:CreateValue("R.Acc", "°/s2")
        instance.operationWidget = shared:CreateValue("R.Op", "")
        instance.Reference = o.Up
        instance.Normal = o.Forward
        instance.LocalNormal = construct.orientation.localized.Forward
    elseif axis == AxisControlYaw then
        instance.offsetWidget = shared:CreateValue("Yaw", "°")
        instance.velocityWidget = shared:CreateValue("Y.Vel", "°/s")
        instance.accelerationWidget = shared:CreateValue("Y.Acc", "°/s2")
        instance.operationWidget = shared:CreateValue("Y.Op", "")
        instance.Reference = o.Forward
        instance.Normal = o.Up
        instance.LocalNormal = construct.orientation.localized.Up
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
    return (vel * self.LocalNormal()):len() * rad2deg
end

function control:Acceleration()
    local vel = construct.acceleration.localized.Angular()
    return (vel * self.LocalNormal()):len() * rad2deg
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

        local vecToTarget = self.target.coordinate - construct.position.Current()
        local offset = calc.SignedRotationAngle(self.Normal(), self.Reference(), vecToTarget) * rad2deg

        self.operationWidget:Set("Offset " .. calc.Round(offset, 4))

        local isLeftOf = calc.Sign(offset) == -1
        local isRightOf = calc.Sign(offset) == 1
        local movingLeft = calc.Sign(self:Speed()) == 1
        local movingRight = calc.Sign(self:Speed()) == -1
        local standStill = movingLeft == 0 and movingRight == 0

        local movingTowardsTarget = (isLeftOf and movingRight) or (isRightOf and movingLeft)
        local towardsTarget = calc.Sign(offset)

        local acc = 0
        local maxVel = 5 -- degreees/s
        local brakeAcceleration = 5

        if movingTowardsTarget then
            offset = offset * 0.5
        end

        self.pid:inject(offset)
        acc = self.pid:get()

        finalAcceleration[self.controlledAxis] = self:Normal() * acc * deg2rad
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
