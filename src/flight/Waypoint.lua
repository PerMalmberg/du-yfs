local alignment = require("flight/AlignmentFunctions")
local r = require("CommonRequire")
local checks = r.checks
local Ternary = r.calc.Ternary
local vehicle = r.vehicle

---@class Waypoint


local waypoint = {}
waypoint.__index = waypoint

---Creates a new Waypoint
---@param destination vec3 The destination
---@param finalSpeed number The final speed to reach when at the waypoint (0 if stopping is intended).
---@param maxSpeed number The maximum speed to to travel at. Less than or equal to finalSpeed.
---@param margin number The number of meters to be within for the waypoint to be considered reached
---@param roll function Function that determines how the constrol aligns its topside (rolls)
---@return table
local function new(destination, finalSpeed, maxSpeed, margin, roll, yawPitch)
    checks.IsVec3(destination, "destination", "waypoint:new")
    checks.IsNumber(finalSpeed, "finalSpeed", "waypoint:new")
    checks.IsNumber(maxSpeed, "maxSpeed", "waypoint:new")
    checks.IsNumber(margin, "margin", "waypoint:new")
    checks.IsFunction(roll, "roll", "waypoint:new")
    checks.IsFunction(yawPitch, "yawPitch", "waypoint:new")

    local o = {
        destination = destination,
        finalSpeed = finalSpeed,
        -- Guard against bad settings.
        maxSpeed = Ternary(finalSpeed > maxSpeed, finalSpeed, maxSpeed),
        margin = margin,
        rollFunc = roll,
        yawPitchFunc = yawPitch,
        yawPitchDirection = nil, -- Fixed target direction, vec3
        precisionMode = false
    }

    setmetatable(o, waypoint)

    return o
end

function waypoint:FinalSpeed()
    return self.finalSpeed
end

function waypoint:MaxSpeed()
    return self.maxSpeed
end

function waypoint:Margin()
    return self.margin
end

function waypoint:Reached()
    return self:DistanceTo() <= self.margin
end

function waypoint:DistanceTo()
    return (self.destination - vehicle.position.Current()):len()
end

function waypoint:DirectionTo()
    return (self.destination - vehicle.position.Current()):normalize_inplace()
end

function waypoint:GetPrecisionMode()
    return self.precisionMode
end

function waypoint:SetPrecisionMode(value)
    self.precisionMode = value
end

function waypoint:LockDirection(direction, forced)
    if self.yawPitchDirection == nil or forced then
        self.yawPitchDirection = direction
        self.yawPitchFunc = alignment.YawPitchKeepWaypointDirectionOrthogonalToVerticalReference
    end
end

function waypoint:DirectionLocked()
    return self.yawPitchDirection ~= nil
end

function waypoint:Roll(previousWaypoint)
    if self.rollFunc ~= nil then
        return self.rollFunc(self, previousWaypoint)
    end

    return nil
end

function waypoint:YawAndPitch(previousWaypoint)
    if self.yawPitchFunc ~= nil then
        return self.yawPitchFunc(self, previousWaypoint)
    end

    return nil
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
