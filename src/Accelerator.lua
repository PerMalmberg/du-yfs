local constants = require("Constants")
local calc = require("Calc")
require("Enum")

local abs = math.abs
local max = math.max

local acc = {}
acc.__index = acc

local Mode =
    Enum {
    "IDLE",
    "ACC",
    "MOVE_RAMP_UP",
    "MOVE_RAMP_DOWN"
}

local function new()
    local instance = {
        targetSpeed = 0,
        initialDirection = 0,
        acceleration = 0,
        forwardDirection = 0,
        mode = Mode.ACC
    }

    setmetatable(instance, acc)

    return instance
end

function acc:AccelerateTo(currentSpeed, targetSpeed, seconds, forwardDirection)
    self.mode = Mode.ACC
    self.targetSpeed = abs(targetSpeed)
    self.initialDirection = calc.Sign(currentSpeed)
    self.acceleration = calc.AbsDiff(targetSpeed, currentSpeed) / seconds
    self.forwardDirection = forwardDirection
end

function acc:MoveDistance(currentSpeed, distance, time, forwardDirection)
    self.mode = Mode.MOVE_RAMP_UP
    self.initialDirection = calc.Sign(currentSpeed)
    self.forwardDirection = forwardDirection
    -- Make two-part acceleration, ramp-up then ramp-down
    -- S = V0*t + 0.5*a*t^2
    -- Half in each part
    -- QQQ if currently moving in the wrong direction, we need to stop first
    distance = distance / 2
    time = time / 2
    self.acceleration = 2 * (distance - currentSpeed * time) / (time * time)
    self.targetSpeed = self.acceleration * time
end

local function accelerateToSpeed(targetSpeed, currentSpeed, acceleration, forwardDirection)
    local delta = targetSpeed - abs(currentSpeed)

    if delta > 0 then
        -- Accelerate
        return acceleration * forwardDirection
    else
        -- Decelerate
        return acceleration * -forwardDirection
    end
end

function acc:Feed(currentSpeed)
    local absSpeed = abs(currentSpeed)
    if self.mode == Mode.ACC then
        return accelerateToSpeed(self.targetSpeed, absSpeed, self.acceleration, self.forwardDirection)
    elseif self.mode == Mode.MOVE_RAMP_UP then
        system.print("UP")
        if absSpeed >= self.targetSpeed then
            self.mode = Mode.MOVE_RAMP_DOWN
            self.targetSpeed = 0
        else
            return accelerateToSpeed(self.targetSpeed, absSpeed, self.acceleration, self.forwardDirection)
        end
    elseif self.mode == Mode.MOVE_RAMP_DOWN then
        local speedNextTick = currentSpeed + self.acceleration * constants.flushTick
        local nextDir = calc.Sign(speedNextTick)

        system.print(calc.Sign(speedNextTick) .. " " .. calc.Sign(self.initialDirection))
        system.print("DOWN1")

        if nextDir == self.forwardDirection then
            system.print("DOWN2")
            return accelerateToSpeed(self.targetSpeed, absSpeed, self.acceleration, self.forwardDirection)
        else
            -- Reached destiation
            self.mode = Mode.IDLE
            system.print("Idle")
            return 0
        end
    else
        -- Idle
        return 0
    end
end

return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            return new()
        end
    }
)
