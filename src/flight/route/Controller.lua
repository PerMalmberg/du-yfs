local Point = require("flight/route/Point")
local PointOptions = require("flight/route/PointOptions")
local Route = require("flight/route/Route")
local log = require("CommonRequire").log

local NAMED_POINTS = "NamedPoints"
local NAMED_ROUTES = "NamedRoutes"

local singleton

---@class Controller Route Controller
local Controller = {}
Controller.__index = Controller

function Controller:Instance(bufferedDB)
    if singleton then
        return singleton
    end

    local s = {}
    
    local db = bufferedDB
    local current
    local edit
    local editName

    function s:GetRouteNames()
        local routes = db:Get(NAMED_ROUTES) or {}
        local res = {}
        for name, _ in pairs(routes) do
            if name == editName then
                name = name .. " (editing)"
            end
            table.insert(res, name)
        end

        return res
    end

    ---@param name string The name of the route to load
    ---@return Route A route or nil on failure
    function s:LoadRoute(name)
        local routes = db:Get(NAMED_ROUTES) or {}
        local data = routes[name]

        if data == nil then
            log:Error("No route by name '", name, "' found.")
            return nil
        end

        local route = Route:New()

        for _, point in ipairs(data) do
            local p = Point:New(point.pos, point.waypointRef, PointOptions:New(point.options))

            if p:HasWaypointRef() then
                local wpName = p:WaypointRef()
                log:Debug("Loading waypoint reference '", wpName, "'")
                local wp = s:LoadWaypoint(wpName)
                if wp == nil then
                    log:Error("The referenced waypoint '", wpName, "' was not found")
                    return nil
                end

                p.pos = wp.pos
            end

            route:AddPoint(p)
        end

        edit = route
        editName = name

        log:Info("Route '", name, "' loaded")
        return route
    end

    function s:DeleteRoute(name)
        local routes = db:Get(NAMED_ROUTES) or {}
        local route = routes[name]

        if route == nil then
            log:Error("No route by name '", name, "' found.")
            return nil
        end

        routes[name] = nil
        db:Put(NAMED_ROUTES, routes)
        log:Info("Route '", name, "' deleted")

        if name == editName then
            edit = nil
            editName = nil
            log:Info("No route is currently being edited")
        end
    end

    ---@param name string The name to store the route as
    ---@param route Route The route to store
    function s:StoreRoute(name, route)
        if not edit then
            log:Error("Cannot save, no route currently being edited")
            return
        end

        local routes = db:Get(NAMED_ROUTES) or {}
        local data = {}

        for _, p in ipairs(route:Points()) do
            table.insert(data, p:Persist())
        end

        routes[name] = data
        db:Put(NAMED_ROUTES, routes)
        log:Info("Route '", name, "' saved.")
    end

    ---@param name string The name of the waypoint
    ---@param pos string A ::pos string
    function s:StoreWaypoint(name, pos)
        local waypoints = db:Get(NAMED_POINTS) or {}
        local p = Point:New(pos)
        waypoints[name] = p:Persist()

        db:Put(NAMED_POINTS, waypoints)
        log:Info("Waypoint saved as '", name, "'")
    end

    function s:GetWaypoints()
        local namedPositions = db:Get(NAMED_POINTS) or {}

        local names = {}

        -- Create a list of the names
        for name, _ in pairs(namedPositions) do
            table.insert(names, name)
        end

        table.sort(names)

        local res = {}
        for _, name in pairs(names) do
            table.insert(res,{name = name, point = s:LoadWaypoint(name, namedPositions)})
        end

        return res
    end

    function s:LoadWaypoint(name, waypoints)
        waypoints = waypoints or db:Get(NAMED_POINTS) or {}
        local point = waypoints[name]

        if point == nil then
            log:Error("No waypoint by name '", name, "' found.")
            return nil
        end

        return Point:New(point.pos)
    end

    ---@return Point Returns the next point in the route or nil if it is the last.
    function s:CurrentRoute()
        return current
    end

    function s:CurrentEdit()
        return edit
    end

    function s:ActivateRoute(name)
        if name == nil then
            current = Route:New()
            return false
        end

        if name == editName then
            log:Info("Activating route currently being edited, forcing save.")
            s:StoreRoute(editName, edit)
        end

        local r = s:LoadRoute(name)

        if r ~= nil then
            current = r
            log:Info("Route activated: ", name)
        end

        return true
    end

    function s:CreateRoute(name)
        if name == nil or #name == 0 then
            log:Error("No name provided for route")
            return false
        end

        edit = Route:New()
        editName = name

        log:Info("Route '", name, "' created (but not yet saved)")
        return true
    end

    function s:SaveRoute()
        if edit then
            s:StoreRoute(editName, edit)
        else
            log:Error("No route currently opened for edit.")
        end
    end

    singleton = setmetatable(s, Controller)
    return singleton
end

return Controller