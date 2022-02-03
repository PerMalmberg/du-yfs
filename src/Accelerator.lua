local constants = require("Constants")
local calc = require("Calc")
require("Enum")

local abs = math.abs
local max = math.max

local acc = {}
acc.__index = acc

local Mode =
    Enum {
    "ACC",
    "MOVE_RAMP_UP",
    "MOVE_RAMP_DOWN"
}

local function new()
    local instance = {
        targetSpeed = 0,
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
    self.acceleration = calc.AbsDiff(targetSpeed, currentSpeed) / seconds
    self.forwardDirection = forwardDirection
end

function acc:MoveDistance(currentSpeed, distance, time, forwardDirection)
    self.mode = Mode.MOVE_RAMP_UP
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
    system.print(targetSpeed .. "  " .. currentSpeed .. "  " .. delta)
    if delta > 0 then
        -- Accelerate
        return acceleration * forwardDirection
    else
        -- Decelerate
        return acceleration * -forwardDirection
    end
end

function acc:Feed(currentSpeed)
    if self.mode == Mode.ACC then
        return accelerateToSpeed(self.targetSpeed, abs(currentSpeed), self.acceleration, self.forwardDirection)
    elseif self.mode == Mode.MOVE_RAMP_UP then
        if abs(currentSpeed) >= self.targetSpeed then
            self.mode = Mode.MOVE_RAMP_DOWN
            self.targetSpeed = 0
        else
            return accelerateToSpeed(self.targetSpeed, abs(currentSpeed), self.acceleration, self.forwardDirection)
        end
    elseif self.mode == Mode.MOVE_RAMP_DOWN then
        if abs(currentSpeed) > 0 then
            return accelerateToSpeed(self.targetSpeed, abs(currentSpeed), self.acceleration, self.forwardDirection)
        else
            -- Reached destiation
            return 0
        end
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
