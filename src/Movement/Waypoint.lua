local diag = require("Diagnostics")()
local construct = require("abstraction/Construct")()

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
        acceleration = 15
    }

    setmetatable(o, waypoint)

    return o
end

function waypoint:Reached(position)
    return (position - self.destination):len() <= self.margin
end

function waypoint:Roll()
    if self.rollFunc ~= nil then
        return self.rollFunc(self)
    end

    return nil
end

function waypoint:YawAndPitch()
    if self.yawPitchFunc ~= nil then
        return self.yawPitchFunc(self)
    end

    return nil
end

function RollTopsideAwayFromGravity(waypoint)
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
