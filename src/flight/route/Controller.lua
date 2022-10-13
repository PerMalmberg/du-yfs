local Point = require("flight/route/Point")
local PointOptions = require("flight/route/PointOptions")
local Route = require("flight/route/Route")
local log = require("debug/Log")()
local universe = require("universe/Universe").Instance()
require("util/Table")

---@alias NamedWaypoint {name:string, point:Point}
---@alias WaypointMap table<string,Point>
---@module "storage/BufferedDB"

---@class Controller
---@field GetRouteNames fun()string[]
---@field LoadRoute fun(name:string):Route|nil
---@field DeleteRoute fun(name:string)
---@field StoreRoute fun(name:string, route:Route)
---@field StoreWaypoint fun(name:string, pos:string):boolean
---@field GetWaypoints fun():NamedWaypoint[]
---@field LoadWaypoint fun(name:string, waypoints?:table<string,Point>):Point|nil
---@field CurrentRoute fun():Route|nil
---@field CurrentEdit fun():Route|nil
---@field ActivateRoute fun(name:string):boolean
---@field ActivateTempRoute fun():Route
---@field CreateRoute fun(name:string):Route|nil
---@field SaveRoute fun()
---@field Count fun():integer

local Controller = {}
Controller.__index = Controller
local singleton

Controller.NAMED_POINTS = "NamedPoints"
Controller.NAMED_ROUTES = "NamedRoutes"

---Create a new route controller instance
---@param bufferedDB BufferedDB
---@return Controller
function Controller.Instance(bufferedDB)
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
        local routes = db.Get(Controller.NAMED_ROUTES) or {}
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
    function s.LoadRoute(name)
        local routes = db.Get(Controller.NAMED_ROUTES) or {}
        local data = routes[name]

        if data == nil then
            log:Error("No route by name '", name, "' found.")
            return nil
        end

        local route = Route.New()

        for _, point in ipairs(data) do
            local p = Point.New(point.pos, point.waypointRef, PointOptions.New(point.options))

            if p.HasWaypointRef() then
                local wpName = p.WaypointRef()
                log:Debug("Loading waypoint reference '", wpName, "'")
                local wp = s.LoadWaypoint(wpName)
                if wp == nil then
                    log:Error("The referenced waypoint '", wpName, "' was not found")
                    return nil
                end

                -- Replace the point
                p = Point.New(wp.Pos(), p.WaypointRef(), p.Options())
            end

            route.AddPoint(p)
        end

        edit = route
        editName = name

        log:Info("Route '", name, "' loaded")
        return route
    end

    ---Deletes the named route
    ---@param name string
    function s.DeleteRoute(name)
        local routes = db.Get(Controller.NAMED_ROUTES) or {}
        local route = routes[name]

        if route == nil then
            log:Error("No route by name '", name, "' found.")
            return
        end

        routes[name] = nil
        db.Put(Controller.NAMED_ROUTES, routes)
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
    function s.StoreRoute(name, route)
        if not edit then
            log:Error("Cannot save, no route currently being edited")
            return
        end

        local routes = db.Get(Controller.NAMED_ROUTES) or {}
        local data = {}

        for _, p in ipairs(route.Points()) do
            table.insert(data, p.Persist())
        end

        routes[name] = data
        db.Put(Controller.NAMED_ROUTES, routes)
        log:Info("Route '", name, "' saved.")
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

        local waypoints = db.Get(Controller.NAMED_POINTS) or {}
        waypoints[name] = Point.New(pos).Persist()

        db.Put(Controller.NAMED_POINTS, waypoints)
        log:Info("Waypoint saved as '", name, "'")
        return true
    end

    ---Returns a list of all waypoints
    ---@return NamedWaypoint[]
    function s.GetWaypoints()
        local namedPositions = db.Get(Controller.NAMED_POINTS) or {}

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
        waypoints = waypoints or db.Get(Controller.NAMED_POINTS) or {}
        local pointData = waypoints[name]

        if pointData == nil then
            log:Error("No waypoint by name '", name, "' found.")
            return nil
        end

        return Point.LoadFromPOD(pointData)
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
    ---@return boolean
    function s.ActivateRoute(name)
        if not name or string.len(name) == 0 then
            log:Error("No route name provided")
            return false
        end
        if editName ~= nil and name == editName and edit ~= nil then
            log:Info("Activating route currently being edited, forcing save.")
            s.StoreRoute(editName, edit)
        end

        current = s.LoadRoute(name)

        if current == nil then
            return false
        else
            log:Info("Route activated: ", name)
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

    ---Saves the currently added route
    function s.SaveRoute()
        if edit and editName ~= nil then
            s.StoreRoute(editName, edit)
        else
            log:Error("No route currently opened for edit.")
        end
    end

    singleton = setmetatable(s, Controller)
    return singleton
end

return Controller
