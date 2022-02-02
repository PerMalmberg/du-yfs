local constants = require("Constants")
local calc = require("Calc")

local abs = math.abs
local max = math.max

local acc = {}
acc.__index = acc

local function new()
    local instance = {
        targetSpeed = 0,
        acceleration = 0,
        forwardDirection = 0,
        speedChangePerTick = 0
    }

    setmetatable(instance, acc)

    return instance
end

function acc:AccelerateTo(currentSpeed, targetSpeed, seconds, forwardDirection)
    self.targetSpeed = abs(targetSpeed)
    self.acceleration = calc.AbsDiff(targetSpeed, currentSpeed) / seconds
    self.forwardDirection = forwardDirection
    self.speedChangePerTick = self.acceleration * constants.flushTick
end

function acc:Feed(currentSpeed)
    local delta = self.targetSpeed - abs(currentSpeed)
    system.print(self.targetSpeed .. "  " .. currentSpeed .. "  " .. delta)
    if delta > 0 then
        -- Accelerate
        return self.acceleration * self.forwardDirection
    else
        -- Decelerate
        return self.acceleration * -self.forwardDirection
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
