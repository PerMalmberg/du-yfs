--[[
    A route holds a series of Point that each contains the data needed to create a Waypoint.
    When loaded, additional points may be inserted to to create a route that is smooth to fly
    and that doesn't pass through a planetary body. Extra points are not persisted.
]]--
local r = require("CommonRequire")
local log = r.log
local checks = r.checks
local vehicle = r.vehicle
local universe = r.universe
local Point = require("flight/route/Point")

---@class Route Represents a route
local Route = {}
Route.__index = Route

function Route:New()
    local s = {}

    local points = {}
    local currentPointIx = 1

    function s:Points()
        return points
    end

    function s:AddPos(positionString)
        checks.IsString(positionString, "positionString", "route:AddPos")

        local pos = universe:ParsePosition(positionString)

        if pos == nil then
            log:Error("Could not add position to route")
            return nil
        end

        return s:AddPoint(Point:New(pos:AsPosString()))
    end

    function s:AddCoordinate(coord)
        checks.IsVec3(coord, "coord", "route:AddCoordinate")

        return s:AddPoint(Point:New(universe:CreatePos(coord):AsPosString()))
    end

    function s:AddWaypointRef(name)
        return s:AddPoint(Point:New("", name))
    end

    function s:AddCurrentPos()
        return s:AddCoordinate(vehicle.position.Current())
    end

    function s:AddPoint(point)
        table.insert(points, point)
        return point
    end

    function s:Clear()
        points = {}
        currentPointIx = 1
    end

    ---@return Point Returns the next point in the route or nil if it is the last.
    function s:Next()
        if s:LastPointReached() then
            return nil
        end

        local p = points[currentPointIx]
        currentPointIx = currentPointIx + 1

        return p
    end

    function s:Dump()
        for _, p in ipairs(points) do
            log:Info(p:Persist())
        end
    end

    function s:LastPointReached()
        return currentPointIx > #points
    end

    return setmetatable(s, Route)
end

return Route