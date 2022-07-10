local universe = require("du-libs:universe/Universe")()

-- This class represents a position in a route.
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

function point:Options()
    return self.options
end

function point:SetOptions(options)
    self.options = options
end

function point:Persist()
    return {
        pos = self.pos,
        waypointRef = self.waypointRef,
        options = self.options
    }
end

function point:Coordinate()
    return universe:ParsePosition(self.pos):Coordinates()
end

local function new(pos, waypointRef, options)
    local instance = {
        pos = pos, -- ::pos string
        waypointRef = waypointRef or "",
        options = options or {} -- Flight options for later use
    }

    setmetatable(instance, point)

    return instance
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