local diag = require("Diagnostics")()
local utc = system.getUtcTime

local targetPoint = {}
targetPoint.__index = targetPoint

local function new(origin, destination, maxSpeed)
    diag:AssertIsVec3(origin, "origin", "targetPoint:new")
    diag:AssertIsVec3(destination, "destination", "targetPoint:new")
    diag:AssertIsNumber(maxSpeed, "maxSpeed", "targetPoint:new")

    local diff = destination - origin

    local instance = {
        origin = origin,
        destination = destination,
        distance = diff:len(),
        direction = diff:normalize(),
        maxSpeed = maxSpeed,
        startTime = nil,
        holdTime = 0,
        lastTime = 0
    }
    return setmetatable(instance, targetPoint)
end

function targetPoint:Current(chaserPosition, maxDistanceAhead)
    local now = utc()

    if self.startTime == nil then
        self.startTime = now
        self.lastTime = now
    end

    local elapsed = now - self.startTime - self.holdTime
    local distance = self.maxSpeed * elapsed
    local pos = self.origin + self.direction * distance

    if distance >= self.distance then
        pos = self.destination
    end

    if (chaserPosition - pos):len() > maxDistanceAhead then
        self.holdTime = self.holdTime + (now - self.lastTime)
    end

    self.lastTime = now

    return pos
end

-- The module
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
