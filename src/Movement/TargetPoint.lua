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
        startTime = nil
    }
    return setmetatable(instance, targetPoint)
end

function targetPoint:Current()
    if self.startTime == nil then
        self.startTime = utc()
    end

    local elapsed = utc() - self.startTime
    local distance = self.maxSpeed * elapsed

    if distance < self.distance then
        return self.origin + self.direction * distance
    else
        return self.destination
    end
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
