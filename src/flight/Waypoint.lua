local diag = require("debug/Diagnostics")()
local construct = require("abstraction/Construct")()
local universe = require("universe/Universe")()

local waypoint = {}
waypoint.__index = waypoint

---Creates a new Waypoint
---@param destination vec3 The destination
---@param maxSpeed number The maximum speed to approach the waypoint at.
---@param margin number The number of meters to be within for the waypoint to be considered reached
---@param roll function Function that determines how the constrol aligns its topside (rolls)
---@return table
local function new(destination, maxSpeed, margin, roll, yawPitch)
    diag:AssertIsVec3(destination, "destination", "waypoint:new")
    diag:AssertIsNumber(maxSpeed, "maxSpeed", "waypoint:new")
    diag:AssertIsNumber(margin, "margin", "waypoint:new")
    diag:AssertIsFunction(roll, "roll", "waypoint:new")
    diag:AssertIsFunction(yawPitch, "yawPitch", "waypoint:new")

    local o = {
        destination = destination,
        maxSpeed = maxSpeed,
        margin = margin,
        rollFunc = roll,
        yawPitchFunc = yawPitch,
        fixedRollPoint = nil, -- Fixed target point, vec3
        fixedYawPatchPoint = nil, -- Fixed target point, vec3
        acceleration = 15
    }

    setmetatable(o, waypoint)

    return o
end

function waypoint:Reached()
    return self:DistanceTo() <= self.margin
end

function waypoint:DistanceTo()
    return (self.destination - construct.position.Current()):len()
end

function waypoint:DirectionTo()
    return (self.destination - construct.position.Current()):normalize_inplace()
end

function waypoint:Roll(previousWaypoint)
    if self.fixedRollPoint ~= nil then
        return fixedRollPoint
    elseif self.rollFunc ~= nil then
        return self.rollFunc(self, previousWaypoint)
    end

    return nil
end

function waypoint:YawAndPitch(previousWaypoint)
    if self.fixedYawPatchPoint ~= nil then
        return self.fixedYawPatchPoint
    elseif self.yawPitchFunc ~= nil then
        return self.yawPitchFunc(self, previousWaypoint)
    end

    return nil
end

function RollTopsideAwayFromNearestBody(waypoint, previousWaypoint)
    local center = universe:ClosestBody().Geography.Center
    local pos = construct.position.Current()
    return pos + (pos - center):normalize_inplace() * 100
end

function RollTopsideAwayFromGravity(waypoint, previousWaypoint)
    -- Presumably we have gravity near a space construct too so we want to align based on that.
    if construct.world.G() > 0 then
        return construct.position.Current() - construct.world.GAlongGravity():normalize() * 100
    else
        return nil -- Don't do alignment in space
    end
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