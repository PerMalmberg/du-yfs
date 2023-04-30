--[[
    A route holds a series of Point that each contains the data needed to create a Waypoint.
    When loaded, additional points may be inserted to to create a route that is smooth to fly
    and that doesn't pass through a planetary body. Extra points are not persisted.
]]
--
local vehicle    = require("abstraction/Vehicle"):New()
local calc       = require("util/Calc")
local log        = require("debug/Log")()
local universe   = require("universe/Universe").Instance()
local Point      = require("flight/route/Point")
local pagination = require("util/Pagination")
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
---@field AdjustRouteBasedOnTarget fun(startPos:Vec3, targetIndex:number)
---@field FindClosestLeg fun(coordinate:Vec3):number,number
---@field Reverse fun()
---@field RemovePoint fun(ix:number):boolean
---@field MovePoint fun(from:number, to:number)
---@field GetRemaining fun(fromPos:Vec3):RouteRemainingInfo
---@field GetPointPage fun(page:integer, perPage:integer):Point[]
---@field GetPageCount fun(perPage:integer):integer


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

    ---@param coordinate Vec3
    ---@return number # Start index
    ---@return number # End index
    function s.FindClosestLeg(coordinate)
        local startIx = 1
        local endIx = 2

        local closest = math.maxinteger
        local prev = universe.ParsePosition(points[1]:Pos())

        for i = 2, #points, 1 do
            local next = universe.ParsePosition(points[i]:Pos())

            if not prev or not next then
                return 1, 2
            end

            local dist = (coordinate - calc.NearestOnLineBetweenPoints(prev.Coordinates(),
                next.Coordinates(), coordinate)):Len()

            -- Find the first closest leg. Any later ones are ignored.
            if dist < closest then
                closest = dist
                startIx = i - 1
                endIx = i
            end

            prev = next
        end

        return startIx, endIx
    end

    ---@param startIx number
    ---@param endIx number
    local function keep(startIx, endIx)
        local toKeep = {}

        for i = 1, #points, 1 do
            if i >= startIx and i <= endIx then
                toKeep[#toKeep + 1] = points[i]
            end
        end

        points = toKeep
    end

    ---Adjust the route so that it will be traveled in the correct direction.
    ---@param startPos Vec3
    ---@param targetIndex number
    function s.AdjustRouteBasedOnTarget(startPos, targetIndex)
        if targetIndex == 0 then
            targetIndex = #points
        end

        -- First find the closest leg indexes
        local startLegStart, startLegEnd = s.FindClosestLeg(startPos)
        local target = universe.ParsePosition(points[targetIndex]:Pos()).Coordinates()
        local targetLegStart, targetLegEnd = s.FindClosestLeg(target)

        print("Start:  " .. startLegStart .. " " .. startLegEnd)
        print("Target: " .. targetLegStart .. " " .. targetLegEnd)

        if startLegStart <= targetLegStart then
            -- Overlapping or target is later in route
            keep(startLegStart, targetLegEnd)
        else
            -- Current pos is later in route than the target.

            -- Check if the target position actually is on the start leg, this happens when the start pos is exactly on the end point of a leg
            local a = universe.ParsePosition(points[startLegStart]:Pos()):Coordinates()
            local b = universe.ParsePosition(points[startLegEnd]:Pos()):Coordinates()
            if targetLegEnd == startLegStart and startPos == calc.NearestOnLineBetweenPoints(a, b, startPos) then
                targetLegStart = startLegStart
                targetLegEnd = startLegEnd
            end

            keep(targetLegStart, startLegEnd)
            s.Reverse()
        end
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

        local v = table.remove(points, from)
        table.insert(points, to, v)

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
        return pagination.Paginate(s.Points(), page, perPage)
    end

    ---@param perPage integer
    ---@return integer
    function s.GetPageCount(perPage)
        return pagination.GetPageCount(s.Points(), perPage)
    end

    return setmetatable(s, Route)
end

return Route
