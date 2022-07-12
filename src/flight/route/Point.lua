local universe = require("du-libs:universe/Universe")()
local PointOptions = require("flight/route/PointOptions")

-- This class represents a position and behavior in a route.
-- Keep data as small as possible.

local point = {}
point.__index = point

function point:Name()
    return self.name
end

function point:Pos()
    return self.pos
end

function point:HasWaypointRef()
    return #self.waypointRef > 0
end

function point:WaypointRef()
    return self.waypointRef
end

function point:SetWaypointRef(name)
    self.waypointRef = name
end

function point:Persist()
    return {
        pos = self.pos,
        waypointRef = self.waypointRef or "",
        options = self.options or {}
    }
end

function point:Coordinate()
    return universe:ParsePosition(self.pos):Coordinates()
end

function point:Options()
    return self.options
end

local function new(pos, waypointRef)
    local instance = {
        pos = pos, -- ::pos string
        waypointRef = waypointRef or "",
        options = PointOptions:New()
    }

    setmetatable(instance, point)

    return instance
end

return setmetatable({ new = new }, { __call = function(_, ...)
    return new(...)
end })