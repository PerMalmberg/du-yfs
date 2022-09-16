local universe = require("CommonRequire").universe
local PointOptions = require("flight/route/PointOptions")
local checks = require("debug/Checks")

-- This class represents a position and behavior in a route.
-- Keep data as small as possible.

---@class Point Represents a point/waypoint in a route
local Point = {}
Point.__index = Point

function Point:New(pos, waypointRef, options)
    options = options or PointOptions:New()
    waypointRef = waypointRef or ""

    checks.IsString(pos, "pos", "Point:New")
    checks.IsString(waypointRef, "waypointRef", "Point:New")
    checks.IsTable(options, "options", "Point:New")

    local s = {}

    local position = pos -- ::pos string
    local wpRef = waypointRef or ""
    local opt = options or PointOptions:New()

    function s:Pos()
        return position
    end

    function s:HasWaypointRef()
        return wpRef and #wpRef > 0
    end

    function s:WaypointRef()
        return wpRef
    end

    function s:SetWaypointRef(ref)
        wpRef = ref
    end

    function s:Persist()
        -- this table determines how points are stored
        return {
            pos = opt,
            waypointRef = wpRef or "",
            options = opt:Data() or {}
        }
    end

    function s:Coordinate()
        return universe:ParsePosition(position):Coordinates()
    end

    function s:Options()
        return opt
    end

    return setmetatable(s, Point)
end

return Point