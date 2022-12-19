local Point = require("flight/route/Point")
local Route = require("flight/route/Route")
local log = require("debug/Log")()
local universe = require("universe/Universe").Instance()
require("util/Table")

---@alias NamedWaypoint {name:string, point:Point}
---@alias WaypointMap table<string,Point>
---@module "storage/BufferedDB"

---@class RouteController
---@field GetRouteNames fun()string[]
---@field EditRoute fun(name:string):Route|nil
---@field DeleteRoute fun(name:string)
---@field StoreRoute fun(name:string, route:Route):boolean
---@field StoreWaypoint fun(name:string, pos:string):boolean
---@field GetWaypoints fun():NamedWaypoint[]
---@field LoadWaypoint fun(name:string, waypoints?:table<string,Point>):Point|nil
---@field DeleteWaypoint fun(name:string):boolean
---@field CurrentRoute fun():Route|nil
---@field CurrentEdit fun():Route|nil
---@field ActivateRoute fun(name:string, order:RouteOrder|nil):boolean
---@field ActivateTempRoute fun():Route
---@field CreateRoute fun(name:string):Route|nil
---@field ReverseRoute fun():boolean
---@field SaveRoute fun():boolean
---@field Count fun():integer

local RouteController = {}
RouteController.__index = RouteController
local singleton

RouteController.NAMED_POINTS = "NamedPoints"
RouteController.NAMED_ROUTES = "NamedRoutes"

---Create a new route controller instance
---@param bufferedDB BufferedDB
---@return RouteController
function RouteController.Instance(bufferedDB)
    if singleton then
        return singleton
    end

    local s = {}

    local db = bufferedDB
    local current ---@type Route|nil
    local edit ---@type Route|nil
    local editName ---@type string|nil

    ---Returns the the name of all routes, with "(editing)" appended to the one currently being edited.
    ---@return string[]
    function s.GetRouteNames()
        local routes = db.Get(RouteController.NAMED_ROUTES) or {}
        local res = {} ---@type string[]
        for name, _ in pairs(routes) do
            if name == editName then
                name = name .. " (editing)"
            end
            table.insert(res, name)
        end

        return res
    end

    ---Returns the number of routes
    ---@return integer
    function s.Count()
        return TableLen(s.GetRouteNames())
    end

    ---Loads a named route
    ---@param name string The name of the route to load
    ---@return Route|nil
    function s.loadRoute(name)

        local routes = db.Get(RouteController.NAMED_ROUTES) or {}
        local data = routes[name]

        if data == nil then
            log:Error("No route by name '", name, "' found.")
            return nil
        end

        local route = Route.New()

        for _, point in ipairs(data) do
            local p = Point.LoadFromPOD(point)

            if p.HasWaypointRef() then
                local wpName = p.WaypointRef()
                log:Debug("Loading waypoint reference '", wpName, "'")
                local wp = s.LoadWaypoint(wpName)
                if wp == nil then
                    log:Error("The referenced waypoint '", wpName, "' was not found")
                    return nil
                end

                -- Replace the point
                p = Point.New(wp.Pos(), wpName, p.Options())
            end

            route.AddPoint(p)
        end

        log:Info("Route '", name, "' loaded")

        return route
    end

    ---Loads a named route and makes it available for editing
    ---@param name string The name of the route to load
    ---@return Route|nil
    function s.EditRoute(name)
        edit = s.loadRoute(name)

        if edit == nil then return end
        editName = name

        return edit
    end

    ---Deletes the named route
    ---@param name string
    function s.DeleteRoute(name)
        local routes = db.Get(RouteController.NAMED_ROUTES) or {}
        local route = routes[name]

        if route == nil then
            log:Error("No route by name '", name, "' found.")
            return
        end

        routes[name] = nil
        db.Put(RouteController.NAMED_ROUTES, routes)
        log:Info("Route '", name, "' deleted")

        if name == editName then
            edit = nil
            editName = nil
            log:Info("No route is currently being edited")
        end
    end

    ---Store the route under the given name
    ---@param name string The name to store the route as
    ---@param route Route The route to store
    ---@return boolean
    function s.StoreRoute(name, route)
        if not edit then
            log:Error("Cannot save, no route currently being edited")
            return false
        end

        local routes = db.Get(RouteController.NAMED_ROUTES) or {}
        local data = {}

        for _, p in ipairs(route.Points()) do
            table.insert(data, p.Persist())
        end

        routes[name] = data
        db.Put(RouteController.NAMED_ROUTES, routes)
        log:Info("Route '", name, "' saved.")
        return true
    end

    ---Stores a waypoint under the given name
    ---@param name string The name of the waypoint
    ---@param pos string A ::pos string
    ---@return boolean
    function s.StoreWaypoint(name, pos)
        local p = universe.ParsePosition(pos)
        if p == nil then return false end
        if name == nil or string.len(name) == 0 then
            log:Error("No name provided")
            return false
        end

        local waypoints = db.Get(RouteController.NAMED_POINTS) or {}
        waypoints[name] = Point.New(pos).Persist()

        db.Put(RouteController.NAMED_POINTS, waypoints)
        log:Info("Waypoint saved as '", name, "'")
        return true
    end

    ---Returns a list of all waypoints
    ---@return NamedWaypoint[]
    function s.GetWaypoints()
        local namedPositions = db.Get(RouteController.NAMED_POINTS) or {}

        local names = {}

        -- Create a list of the names
        for name, _ in pairs(namedPositions) do
            table.insert(names, name)
        end

        table.sort(names)

        local res = {} ---@type NamedWaypoint[]
        for _, name in pairs(names) do
            table.insert(res, { name = name, point = s.LoadWaypoint(name, namedPositions) })
        end

        return res
    end

    ---Loads a waypoint by the given name
    ---@param name string Nave of waypoint to load
    ---@param waypoints? WaypointMap An optional table to load from
    ---@return Point|nil
    function s.LoadWaypoint(name, waypoints)
        waypoints = waypoints or db.Get(RouteController.NAMED_POINTS) or {}
        local pointData = waypoints[name]

        if pointData == nil then
            return nil
        end

        return Point.LoadFromPOD(pointData)
    end

    ---Deletes a waypoint
    ---@param name string
    function s.DeleteWaypoint(name)
        local waypoints = db.Get(RouteController.NAMED_POINTS) or {}
        local found = waypoints[name] ~= nil
        if found then
            waypoints[name] = nil
            db.Put(RouteController.NAMED_POINTS, waypoints)
        else
            log:Error("No waypoint by name '", name, "' found.")
        end

        return found
    end

    ---Returns the current route or nil if none is active
    ---@return Route|nil
    function s.CurrentRoute()
        return current
    end

    ---Returns the route currently being edited or nil
    ---@return Route|nil
    function s.CurrentEdit()
        return edit
    end

    ---Activate the route by the given name
    ---@param name string
    ---@param order RouteOrder|nil The order the route shall be followed, or nil for FORWARD
    ---@return boolean
    function s.ActivateRoute(name, order)
        order = order or RouteOrder.FORWARD

        if not name or string.len(name) == 0 then
            log:Error("No route name provided")
            return false
        end

        if editName ~= nil and name == editName and edit ~= nil then
            log:Info("Cannot activate route currently being edited, please save first.")
            return false
        end

        current = s.loadRoute(name)

        if current == nil then
            return false
        else
            log:Info("Route activated: ", name)
        end

        if order == RouteOrder.REVERSED then
            log:Info("Reversing route '", name, "'")
            current.Reverse()
        end

        return true
    end

    ---Activate a temporary, empty, route
    ---@return Route
    function s.ActivateTempRoute()
        current = Route.New()
        return current
    end

    ---Creates a route
    ---@param name string
    ---@return Route|nil
    function s.CreateRoute(name)
        if name == nil or #name == 0 then
            log:Error("No name provided for route")
            return nil
        end

        edit = Route.New()
        editName = name

        log:Info("Route '", name, "' created (but not yet saved)")
        return edit
    end

    ---Saves the currently edited route
    ---@return boolean
    function s.SaveRoute()
        local res = false
        if edit and editName ~= nil then
            res = s.StoreRoute(editName, edit)
            editName = nil
            edit = nil
            log:Info("Closed for editing.")
        else
            log:Error("No route currently opened for edit.")
        end

        return res
    end

    ---Reverses the route currently being edited
    ---@return boolean
    function s.ReverseRoute()
        local res = false

        if edit and editName ~= nil then
            edit.Reverse()
            res = true
        else
            log:Error("No route currently open for edit.")
        end

        return res
    end

    singleton = setmetatable(s, RouteController)
    return singleton
end

return RouteController
