local checks = require("du-libs:debug/Checks")
local vehicle = require("du-libs:abstraction/Vehicle")()
local deg2rad = math.rad

local waypoint = {}
waypoint.__index = waypoint

---Creates a new Waypoint
---@param destination vec3 The destination
---@param maxSpeed number The maximum speed to approach the waypoint at.
---@param margin number The number of meters to be within for the waypoint to be considered reached
---@param roll function Function that determines how the constrol aligns its topside (rolls)
---@return table
local function new(destination, maxSpeed, margin, roll, yawPitch)
    checks.IsVec3(destination, "destination", "waypoint:new")
    checks.IsNumber(maxSpeed, "maxSpeed", "waypoint:new")
    checks.IsNumber(margin, "margin", "waypoint:new")
    checks.IsFunction(roll, "roll", "waypoint:new")
    checks.IsFunction(yawPitch, "yawPitch", "waypoint:new")

    local o = {
        destination = destination,
        maxSpeed = maxSpeed,
        margin = margin,
        rollFunc = roll,
        yawPitchFunc = yawPitch,
        yawPitchDirection = nil, -- Fixed target direction, vec3
    }

    setmetatable(o, waypoint)

    return o
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

function waypoint:OneTimeSetYawPitchDirection(direction, yawPitchFunc)
    if self.yawPitchDirection == nil then
        self.yawPitchDirection = direction
        self.yawPitchFunc = yawPitchFunc
    end
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

function waypoint:RotateAroundAxis(degrees, axis, rotationPoint)
    local rad = deg2rad(degrees)
    axis:normalize_inplace()

    local v = self.destination - rotationPoint
    self.destination = v:rotate(rad, axis) + rotationPoint

    if self.yawPitchDirection ~= nil then
        self.yawPitchDirection = self.yawPitchDirection:rotate(rad, axis)
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