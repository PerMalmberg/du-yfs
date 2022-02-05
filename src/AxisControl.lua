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
local offsetUpdateInterval = 0.5 / constants.flushTick -- 0.5 seconds

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
        flushHandlerId = nil,
        updateHandlerId = nil,
        offsetWidget = nil,
        velocityWidget = nil,
        accelerationWidget = nil,
        operationWidget = nil,
        torqueGroup = EngineGroup("torque"),
        accelerator = Accelerator(),
        maxAcceleration = 360 / 4, -- start value, degrees per second,
        target = {
            speed = 0,
            currentOffset = 0,
            lastOffset = 0,
            coordinate = nil,
            tickUntilUpdate = offsetUpdateInterval
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

function control:BrakeAngle(speed, angularDistance)
    return speed * speed / angularDistance
end

function control:CalculateTargetSpeed()
    -- In what direction is the target moving?
    local dir = self:RelativeTargetMovementDirection(self.target.lastOffset, self.target.currentOffset)
end

function control:RelativeTargetMovementDirection(lastOffset, newOffset)
    -- Round these to handle the fact that things are moving in the world, even though they appear static
    lastOffset = calc.Round(lastOffset, 5)
    newOffset = calc.Round(newOffset, 5)

    local lSign = calc.Sign(lastOffset)
    local nSign = calc.Sign(newOffset)

    local dirs = constants.direction

    local n = abs(newOffset)
    local l = abs(lastOffset)

    -- Assume standstill
    local res = dirs.still

    if lSign == nSign then
        -- Same side
        if lastOffset > 0 then
            -- Left side
            if l > n then
                res = dirs.clockwise
            elseif l < n then
                res = dirs.counterClockwise
            end
        elseif lastOffset < 0 then
            -- Right side
            if l > n then
                res = dirs.counterClockwise
            elseif l < n then
                res = dirs.clockwise
            end
        end
    else
        -- Different sides, need to detect if passing infront or behind ourselves as the sign change is reversed
        local reverse = -1
        if l > 0.5 and n > 0.5 then
            reverse = 1
        end

        if lSign == dirs.rightOf and nSign == dirs.leftOf then
            res = constants.direction.counterClockwise
        elseif lSign == dirs.leftOf and nSign == dirs.rightOf then
            res = dirs.clockwise
        end

        res = res * reverse
    end
    --[[
    if res == dirs.clockwise then
        self.operationWidget:Set("C")
    elseif res == dirs.counterClockwise then
        self.operationWidget:Set("CC")
    else
        self.operationWidget:Set("S")
    end
]]
    return res
end

function control:Flush()
    if self.target.coordinate ~= nil then
        --self:CalculateTargetSpeed()
        -- To turn towards the target, we want to apply an accelecation with the same sign as the offset.
        --local offsetDegrees = offset * 180
        --self.offsetWidget:Set(offsetDegrees)

        -- Positive offset means we're right of target, clock-wise
        -- Postive acceleration turns counter-clockwise
        -- Positive velocity means we're turning counter-clockwise

        local angVel = self:Speed()
        local velSign = calc.Sign(angVel)
        --local isLeft = offset < 0
        --local isRight = offset > 0
        local movingLeft = velSign == 1
        local movingRight = velSign == -1

        --[[
            local directionToTarget
        if isLeft then
            directionToTarget = -1
        elseif isRight then
            directionToTarget = 1
        else
            directionToTarget = 0
        end
]]
        --[[if self.controlledAxis == AxisControlYaw then
            if self.foo == nil or not self.foo then
                self.foo = true
                --if self.accelerator:IsIdle() then
                self.accelerator:MoveDistance(self:Speed(), offsetDegrees, 1, directionToTarget)
            --end
            end

            local acc = self.accelerator:Feed(self:Speed())
            self:SetAcceleration(acc)
        end]]
        system.print(self:RelativeTargetMovementDirection(self.target.lastOffset, self.target.currentOffset))

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
    local target = self.target
    target.tickUntilUpdate = target.tickUntilUpdate - 1
    if target.tickUntilUpdate <= 0 then
        target.lastOffset = target.currentOffset
        target.currentOffset = calc.AlignmentOffset(construct.position.Current(), self.target.coordinate, self.Forward(), self.Right())
        target.tickUntilUpdate = offsetUpdateInterval
    end

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
