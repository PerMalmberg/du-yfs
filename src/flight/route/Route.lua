--[[
    A route holds a series of Point that each contains the data needed to create a Waypoint.
    When loaded, additional points may be inserted to to create a route that is smooth to fly
    and that doesn't pass through a planetary body. Extra points are not persisted.
]]
--
local PointOptions = require("flight/route/PointOptions")
local vehicle      = require("abstraction/Vehicle"):New()
local calc         = require("util/Calc")
local log          = require("debug/Log").Instance()
local universe     = require("universe/Universe").Instance()
local Point        = require("flight/route/Point")
local pagination   = require("util/Pagination")
require("util/Table")

---@alias RouteRemainingInfo {Legs:integer, TotalDistance:number}

---@class Route Represents a route
---@field New fun():Route
---@field Points fun():Point[]
---@field AddPos fun(positionString:string):Point
---@field AddCoordinate fun(coord:Vec3):Point
---@field AddWaypointRef fun(namedWaypoint:string, pos?:string):Point|nil
---@field AddCurrentPos fun():Point
---@field AddPoint fun(sp:Point)
---@field SetPointOption fun(pointIndex:number, optionName:string, value:string|boolean|number):boolean
---@field GetPointOption fun(pointIndex:number, optionName:string, default:string|boolean|nil):string|number|boolean|nil
---@field Clear fun()
---@field Next fun():Point|nil
---@field Peek fun():Point|nil
---@field LastPointReached fun():boolean
---@field AdjustRouteBasedOnTarget fun(startPos:Vec3, targetIndex:number)
---@field FindClosestLeg fun(coordinate:Vec3):number,number
---@field FindClosestPositionAlongRoute fun(coord:Vec3):Vec3
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

    ---@param ix integer
    ---@return boolean
    local function checkBounds(ix)
        return ix > 0 and ix <= #points
    end

    ---@param ix number
    ---@return Vec3
    local function coordsFromPoint(ix)
        return universe.ParsePosition(points[ix]:Pos()):Coordinates()
    end
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
            log.Error("Could not add position to route")
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
    ---@param pos? string The ::pos{} string. This parameter is mainly used when editing routes to make the position available for the UI.
    ---@return Point|nil
    function s.AddWaypointRef(name, pos)
        if name == nil or #name == 0 then
            return nil
        end
        return s.AddPoint(Point.New(pos or "", name))
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

    ---@param pointIndex integer
    ---@param optionName string
    ---@param value string|boolean|number
    ---@return boolean
    function s.SetPointOption(pointIndex, optionName, value)
        if checkBounds(pointIndex) then
            points[pointIndex].Options().Set(optionName, value)
            return true
        else
            log.Error("Point index outside bounds")
            return false
        end
    end

    ---@param pointIndex number
    ---@param optionName string
    ---@param default string|number|boolean|nil
    ---@return string|number|boolean|nil
    function s.GetPointOption(pointIndex, optionName, default)
        if checkBounds(pointIndex) then
            local opt = points[pointIndex].Options()
            return opt.Get(optionName, default)
        else
            log.Error("Point index outside bounds")
        end

        return default
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

    local function reverse()
        -- To ensure that we hold the same direction going backwards as we did when going forward,
        -- we must shift the directions one step left before reversing.
        -- Note that this is a destructive operation as we loose the direction on the first point.
        for i = 1, #points - 1 do
            points[i].SetOptions(points[i + 1].Options())
        end

        ReverseInplace(points)
    end

    ---@param coordinate Vec3
    ---@return number # Start index
    ---@return number # End index
    function s.FindClosestLeg(coordinate)
        local startIx = 1
        local endIx = 2

        local closest = math.maxinteger
        local prev = coordsFromPoint(1)

        for i = 2, #points, 1 do
            local next = coordsFromPoint(i)

            if not prev or not next then
                return 1, 2
            end

            local dist = (coordinate - calc.NearestOnLineBetweenPoints(prev, next, coordinate)):Len()

            -- Find the first closest leg. If a leg at the same distance is found, it will be ignored.
            if dist < closest then
                closest = dist
                startIx = i - 1
                endIx = i
            end

            prev = next
        end

        return startIx, endIx
    end

    ---@param coord Vec3
    ---@return Vec3
    function s.FindClosestPositionAlongRoute(coord)
        local startIx, endIx = s.FindClosestLeg(coord)
        return calc.NearestOnLineBetweenPoints(coordsFromPoint(startIx), coordsFromPoint(endIx), coord)
    end

    ---@param startIx number
    ---@param endIx number
    local function keep(startIx, endIx)
        local toKeep = {}

        for i = startIx, endIx do
            local skippable = points[i].Options().Get(PointOptions.SKIPPABLE, false)
            if i == startIx or i == endIx or not skippable then
                toKeep[#toKeep + 1] = points[i]
            end
        end

        points = toKeep
    end

    ---Replaces a point in the route, keping only direction option
    ---@param ix number
    ---@param newPos Vec3
    ---@param point Point Optional point to take direction from. If left out, it is taken from the point being replaced.
    local function replacePointWithDir(ix, newPos, point)
        local dir = point.Options().Get(PointOptions.LOCK_DIRECTION)
        points[ix] = Point.New(universe.CreatePos(newPos):AsPosString())
        points[ix].Options().Set(PointOptions.LOCK_DIRECTION, dir)
    end

    ---Adjust the route so that it will be traveled in the correct direction.
    ---@param startPos Vec3
    ---@param targetIndex number
    function s.AdjustRouteBasedOnTarget(startPos, targetIndex)
        -- Determine if we are before or after the target point
        local closestLeft, closestRight = s.FindClosestLeg(startPos)
        local leftPos = coordsFromPoint(closestLeft)
        local rightPos = coordsFromPoint(closestRight)
        local nearestOnLeg = calc.NearestOnLineBetweenPoints(leftPos, rightPos, startPos)

        local adjChar
        local orgCount = #points

        if closestRight < targetIndex then
            -- Our current pos is earlier in the route than the target index
            keep(closestLeft, targetIndex)
            nearestOnLeg = s.FindClosestPositionAlongRoute(startPos)
            replacePointWithDir(1, nearestOnLeg, points[2])
            adjChar = "A"
        elseif closestRight == targetIndex then
            -- We're currently on the leg that the target index ends.
            keep(closestLeft, targetIndex)
            nearestOnLeg = s.FindClosestPositionAlongRoute(startPos)
            replacePointWithDir(1, nearestOnLeg, points[2])
            adjChar = "B"
        elseif closestLeft == targetIndex then
            -- We're currently on the leg that targetIndex starts
            keep(targetIndex, closestRight)
            reverse()
            nearestOnLeg = s.FindClosestPositionAlongRoute(startPos)
            replacePointWithDir(1, nearestOnLeg, points[1])
            adjChar = "C"
        else
            -- We're currently on a leg after the target index
            keep(targetIndex, closestRight)
            reverse()
            nearestOnLeg = s.FindClosestPositionAlongRoute(startPos)
            replacePointWithDir(1, nearestOnLeg, points[1])
            adjChar = "D"
        end

        log.Info("Route adjusted (", adjChar, ": ", orgCount, " -> ", #points, ")")
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
        local next = coordsFromPoint(nextPointIx + ix)
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
