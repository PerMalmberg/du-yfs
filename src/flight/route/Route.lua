--[[
    A route holds a series of Point that each contains the data needed to create a Waypoint.
    When loaded, additional points may be inserted to to create a route that is smooth to fly
    and that doesn't pass through a planetary body. Extra points are not persisted.
]] --
local vehicle = require("abstraction/Vehicle"):New()
local log = require("debug/Log")()
local universe = require("universe/Universe").Instance()
local Point = require("flight/route/Point")

---@class Route Represents a route
---@field New fun():Route
---@field Points fun():Point[]
---@field AddPos fun(positionString:string):Point
---@field AddCoordinate fun(coord:Vec3):Point
---@field AddWaypointRef fun(namedWaypoint:string):Point|nil
---@field AddCurrentPos fun():Point
---@field AddPoint fun(sp:Point)
---@field Clear fun()
---@field Next fun():Point|nil
---@field LastPointReached fun():boolean


local Route = {}
Route.__index = Route

---Creates a new route
---@return Route
function Route.New()
    local s = {}

    local points = {} ---@type Point[]
    local currentPointIx = 1

    ---Returns all the points in the route
    ---@return Point[]
    function s.Points()
        return points
    end

    ---Adds a ::pos{} string
    ---@param positionString string
    ---@return Point|nil
    function s.AddPos(positionString)
        local pos = universe.ParsePosition(positionString)

        if pos == nil then
            log:Error("Could not add position to route")
            return nil
        end

        return s.AddPoint(Point.New(pos:AsPosString()))
    end

    ---Adds a coordinate to the route
    ---@param coord Vec3
    ---@return Point
    function s.AddCoordinate(coord)
        return s.AddPoint(Point.New(universe.CreatePos(coord):AsPosString()))
    end

    ---Adds a named waypoint to the route
    ---@param name string
    ---@return Point|nil
    function s.AddWaypointRef(name)
        if name == nil or #name == 0 then
            return nil
        end
        return s.AddPoint(Point.New("", name))
    end

    ---Adds the current postion to the route
    ---@return Point
    function s.AddCurrentPos()
        return s.AddCoordinate(vehicle.position.Current())
    end

    ---Adds a Point to the route
    ---@param point Point
    ---@return Point
    function s.AddPoint(point)
        table.insert(points, point)
        return point
    end

    ---Clears the route
    function s.Clear()
        points = {}
        currentPointIx = 1
    end

    ---Returns the next point in the route or nil if it is the last.
    ---@return Point|nil
    function s.Next()
        if s.LastPointReached() then
            return nil
        end

        local p = points[currentPointIx]
        currentPointIx = currentPointIx + 1

        return p
    end

    function s.LastPointReached()
        return currentPointIx > #points
    end

    return setmetatable(s, Route)
end

return Route
