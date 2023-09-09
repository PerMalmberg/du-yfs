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
local Vec3         = require("math/Vec3")
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
---@field CheckBounds fun(ix:integer):boolean
---@field SetPointOption fun(pointIndex:number, optionName:string, value:string|boolean|number):boolean
---@field GetPointOption fun(pointIndex:number, optionName:string, default:string|boolean|nil):string|number|boolean|nil
---@field Clear fun()
---@field Next fun():Point|nil
---@field Peek fun():Point|nil
---@field LastPointReached fun():boolean
---@field AdjustRouteBasedOnTarget fun(startPos:Vec3, targetIndex:number, openGateMaxDistance:number)
---@field FindClosestLeg fun(coordinate:Vec3):number,number
---@field FindClosestPositionAlongRoute fun(coord:Vec3):Vec3
---@field RemovePoint fun(ix:number):boolean
---@field MovePoint fun(from:number, to:number)
---@field GetRemaining fun(fromPos:Vec3):RouteRemainingInfo
---@field GetPointPage fun(page:integer, perPage:integer):Point[]
---@field GetPageCount fun(perPage:integer):integer
---@field WaitForGate fun(current:Vec3, margin:number):boolean
local Route = {}
Route.__index = Route

---Creates a new route
---@return Route
function Route.New()
    local s = {}

    local points = {} ---@type Point[]
    local nextPointIx = 1

    ---@param ix number
    ---@return Vec3
    local function coordsFromPoint(ix)
        return universe.ParsePosition(points[ix]:Pos()):Coordinates()
    end

    ---Returns true if the index is within bounds
    ---@param ix integer
    ---@return boolean
    function s.CheckBounds(ix)
        return ix > 0 and ix <= #points
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
        points[#points + 1] = point
        return point
    end

    ---@param pointIndex integer
    ---@param optionName string
    ---@param value string|boolean|number
    ---@return boolean
    function s.SetPointOption(pointIndex, optionName, value)
        if s.CheckBounds(pointIndex) then
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
        if s.CheckBounds(pointIndex) then
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

    function s.LastPointReached()
        return nextPointIx > #points
    end

    local function reverse()
        -- To ensure that we hold the same direction going backwards as we did when going forward,
        -- we must shift the directions one step left before reversing.
        -- Note that this is a destructive operation as we loose the original direction on the first point.
        for i = 1, #points - 1 do
            points[i].Options().Set(PointOptions.LOCK_DIRECTION, points[i + 1].Options().Get(PointOptions.LOCK_DIRECTION))
        end

        ReverseInplace(points)
    end

    ---Finds the closest point on the route
    ---@param probeCoord Vec3
    ---@return Point
    function s.FindClosestPoint(probeCoord)
        local closest = points[1]
        local closestDist = probeCoord:Dist(coordsFromPoint(1))

        for i = 2, #points, 1 do
            local next = coordsFromPoint(i)
            local distToNext = probeCoord:Dist(next)
            if distToNext < closestDist then
                closest = points[i]
                closestDist = distToNext
            end
        end

        return closest
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

            local dist = coordinate:Dist(calc.NearestOnLineBetweenPoints(prev, next, coordinate))

            -- Find the first closest leg. If a second leg at the same distance is found, it will be ignored.
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

    ---@param startIx number First index to keep
    ---@param endIx number Last index to keep
    ---@param currentLegStartIx number Start index of leg we're currently on
    ---@param currentLegEndIx number End index of the leg we're currently on
    local function keep(startIx, endIx, currentLegStartIx, currentLegEndIx)
        local toKeep = {}

        for i = startIx, endIx do
            local skippable = points[i].Options().Get(PointOptions.SKIPPABLE, false)
            if i == startIx
                or i == endIx
                or i == currentLegStartIx
                or i == currentLegEndIx
                or not skippable then
                toKeep[#toKeep + 1] = points[i]
            end
        end

        points = toKeep
    end

    ---Replaces a point in the route, keping options from original point
    ---@param currentPos Vec3 Current position
    ---@param openGateMaxDistance number
    local function replaceStartPoint(currentPos, openGateMaxDistance)
        local nearestPos = s.FindClosestPositionAlongRoute(currentPos)
        local opt = points[1].Options().Clone()
        opt.Set(PointOptions.GATE,
            opt.Get(PointOptions.GATE, false) and coordsFromPoint(1):Dist(currentPos) < openGateMaxDistance)

        -- Also take direction of the next point, so that when moving to the path we orient in the direction we're going to travel.
        opt.Set(PointOptions.LOCK_DIRECTION, points[2].Options().Get(PointOptions.LOCK_DIRECTION))

        points[1] = Point.New(universe.CreatePos(nearestPos):AsPosString(), nil, opt)
    end

    ---Adjust the route so that it will be traveled in the correct direction.
    ---@param startPos Vec3
    ---@param targetIndex number
    ---@param openGateMaxDistance number
    function s.AdjustRouteBasedOnTarget(startPos, targetIndex, openGateMaxDistance)
        -- Determine if we are before or after the target point
        local legStartIx, legEndIx = s.FindClosestLeg(startPos)

        local adjChar
        local orgCount = #points

        if legEndIx <= targetIndex then
            -- Our current pos is on an earlier or same leg as the one that has the target index
            adjChar = "A"
            keep(legStartIx, targetIndex, legStartIx, legEndIx)
        else
            -- We're currently on a leg after the target index
            adjChar = "B"
            keep(targetIndex, legEndIx, legStartIx, legEndIx)
            reverse()
        end

        replaceStartPoint(startPos, openGateMaxDistance)

        log.Info("Route adjusted (", adjChar, ": ", orgCount, " -> ", #points, ")")
    end

    ---Remove the point at index ix
    ---@param ix number
    function s.RemovePoint(ix)
        if not s.CheckBounds(ix) then return false end

        table.remove(points, ix)
        return true
    end

    ---Move a point from index 'from' to index 'to'
    ---@param from number
    ---@param to number
    function s.MovePoint(from, to)
        if not s.CheckBounds(from) or not s.CheckBounds(to) or to == from then return false end

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

    ---Determines if we should wait for gates to open at the current position.
    ---@param current Vec3
    ---@param margin number
    ---@return boolean
    function s.WaitForGate(current, margin)
        -- Find the closest point
        local closest = s.FindClosestPoint(current)
        local pointPos = universe.ParsePosition(closest:Pos()):Coordinates()

        -- If the point has gate option set and it is within the distance margin then we should wait for the gate.
        return closest.Options().Get(PointOptions.GATE, false) and current:Dist(pointPos) <= margin
    end

    return setmetatable(s, Route)
end

return Route
