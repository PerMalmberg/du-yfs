--[[
    A route holds a series of Point that each contains the data needed to create a Waypoint.
    When loaded, additional points may be inserted to to create a route that is smooth to fly
    and that doesn't pass through a planetary body. Extra points are not persisted.
]]
--
local vehicle  = require("abstraction/Vehicle"):New()
local calc     = require("util/Calc")
local log      = require("debug/Log")()
local universe = require("universe/Universe").Instance()
local Point    = require("flight/route/Point")
require("util/Table")

---@alias RouteRemainingInfo {Legs:integer, TotalDistance:number}

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
---@field Peek fun():Point|nil
---@field LastPointReached fun():boolean
---@field Reverse fun()
---@field RemovePoint fun(ix:number):boolean
---@field MovePoint fun(from:number, to:number)
---@field GetRemaining fun(fromPos:Vec3):RouteRemainingInfo
---@field GetPointPage fun(page:integer, perPage:integer):Point[]
---@field GetPageCount fun(perPage:integer):integer


---@enum RouteOrder
RouteOrder = {
    FORWARD = 1,
    REVERSED = 2
}

local Route = {}
Route.__index = Route

---Creates a new route
---@return Route
function Route.New()
    local s = {}

    local points = {} ---@type Point[]
    local nextPointIx = 1

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
        nextPointIx = 1
    end

    ---Returns the next point in the route or nil if the end has been reached
    ---@return Point|nil
    function s.Next()
        if s.LastPointReached() then return nil end

        local p = points[nextPointIx]
        nextPointIx = nextPointIx + 1

        return p
    end

    ---Get the next point, or nil, without removing it from the route.
    ---@return Point|nil
    function s.Peek()
        if s.LastPointReached() then return nil end
        return points[nextPointIx]
    end

    function s.LastPointReached()
        return nextPointIx > #points
    end

    function s.Reverse()
        ReverseInplace(points)
    end

    local function checkBounds(ix)
        return ix > 0 and ix <= #points
    end

    ---Remove the point at index ix
    ---@param ix number
    function s.RemovePoint(ix)
        if not checkBounds(ix) then return false end

        table.remove(points, ix)
        return true
    end

    ---Move a point from index 'from' to index 'to'
    ---@param from number
    ---@param to number
    function s.MovePoint(from, to)
        if not checkBounds(from) or not checkBounds(to) or to == from then return false end

        table.insert(points, to, points[from])

        if from > to then
            from = from + 1
        end

        table.remove(points, from)
        return true
    end

    ---@param fromPos Vec3
    ---@return RouteRemainingInfo
    function s.GetRemaining(fromPos)
        local total = 0
        local prev

        for i = nextPointIx, #points, 1 do
            local pos = universe.ParsePosition(points[i].Pos())
            if pos then
                if prev then
                    total = total + (prev - pos.Coordinates()):Len()
                end

                prev = pos.Coordinates()
            end
        end

        -- Add distance to next point in route
        local ix = calc.Ternary(s.LastPointReached(), -1, 0)
        local next = universe.ParsePosition(points[nextPointIx + ix].Pos()).Coordinates()
        total = total + (fromPos - next):Len()

        return { Legs = #points - nextPointIx, TotalDistance = total }
    end

    ---@param page integer
    ---@param perPage integer
    ---@return Point[]
    function s.GetPointPage(page, perPage)
        local all = s.Points()

        if #all == 0 then return {} end

        local totalPages = math.ceil(#all / perPage)
        page = calc.Clamp(page, 1, totalPages)

        local startIx = (page - 1) * perPage + 1
        local endIx = startIx + perPage - 1

        local res = {} ---@type Point[]
        local ix = 1

        for i = startIx, endIx, 1 do
            res[ix] = all[i]
            ix = ix + 1
        end

        return res
    end

    ---@param perPage integer
    ---@return integer
    function s.GetPageCount(perPage)
        return math.ceil(#s.Points() / perPage)
    end

    return setmetatable(s, Route)
end

return Route
