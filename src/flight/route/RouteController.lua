local Point    = require("flight/route/Point")
local Route    = require("flight/route/Route")
local log      = require("debug/Log")()
local universe = require("universe/Universe").Instance()
local calc     = require("util/Calc")
local Current  = require("abstraction/Vehicle").New().position.Current
require("util/Table")

---@alias NamedWaypoint {name:string, point:Point}
---@alias WaypointMap table<string,Point>
---@module "storage/BufferedDB"

---@class RouteController
---@field GetRouteNames fun():string[]
---@field GetPageCount fun(perPage:integer):integer
---@field GetRoutePage fun(page:integer, perPage:integer):string[]
---@field EditRoute fun(name:string):Route|nil
---@field DeleteRoute fun(name:string)
---@field StoreRoute fun(name:string, route:Route):boolean
---@field StoreWaypoint fun(name:string, pos:string):boolean
---@field GetWaypoints fun():NamedWaypoint[]
---@field LoadWaypoint fun(name:string, waypoints?:table<string,Point>):Point|nil
---@field DeleteWaypoint fun(name:string):boolean
---@field CurrentRoute fun():Route|nil
---@field CurrentEdit fun():Route|nil
---@field ActivateRoute fun(name:string, order:RouteOrder?, ignoreStartMargin:boolean?):boolean
---@field ActivateTempRoute fun():Route
---@field CreateRoute fun(name:string):Route|nil
---@field ReverseRoute fun():boolean
---@field SaveRoute fun():boolean
---@field Count fun():integer
---@field ActiveRouteName fun():string|nil

local RouteController = {}
RouteController.__index = RouteController
local singleton

RouteController.NAMED_POINTS = "NamedPoints"
RouteController.NAMED_ROUTES = "NamedRoutes"
local startMargin = 10 -- Don't allow a route to be started if we're more than this away from the start of the route

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
    local activeRouteName ---@type string|nil

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

        table.sort(res)

        return res
    end

    ---@param page integer
    ---@param perPage integer
    ---@return string[]
    function s.GetRoutePage(page, perPage)
        local all = s.GetRouteNames()

        if #all == 0 then return {} end

        local totalPages = math.ceil(#all / perPage)
        page = calc.Clamp(page, 1, totalPages)

        local startIx = (page - 1) * perPage + 1
        local endIx = startIx + perPage - 1

        local res = {} ---@type string[]
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
        return math.ceil(#s.GetRouteNames() / perPage)
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
                    log:Error("The referenced waypoint '", wpName, "' in route '", name, "' was not found")
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

    ---Gets the named waypoints
    ---@return WaypointMap
    local function getNamedPoints()
        local w = db.Get(RouteController.NAMED_POINTS) or {}
        ---@cast w WaypointMap
        return w
    end

    ---Returns a list of all waypoints
    ---@return NamedWaypoint[]
    function s.GetWaypoints()
        local namedPositions = getNamedPoints()

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
    ---@param name string|nil Name of waypoint to load
    ---@param waypoints? WaypointMap An optional table to load from
    ---@return Point|nil
    function s.LoadWaypoint(name, waypoints)
        if not name then return nil end
        waypoints = waypoints or getNamedPoints()
        local pointData = waypoints[name]

        if pointData == nil then
            return nil
        end

        return Point.LoadFromPOD(pointData)
    end

    ---Deletes a waypoint
    ---@param name string
    function s.DeleteWaypoint(name)
        local waypoints = getNamedPoints()
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
    ---@param order RouteOrder? The order the route shall be followed, default is FORWARD
    ---@param ignoreStartMargin boolean? If true, the route will be activated even if currently outside the start margin. Default is false.
    ---@return boolean
    function s.ActivateRoute(name, order, ignoreStartMargin)
        order = order or RouteOrder.FORWARD
        if ignoreStartMargin == nil then
            ignoreStartMargin = false
        end

        if not name or string.len(name) == 0 then
            log:Error("No route name provided")
            return false
        end

        if editName ~= nil and name == editName and edit ~= nil then
            log:Info("Cannot activate route currently being edited, please save first.")
            return false
        end

        local route = s.loadRoute(name)

        if route == nil then
            return false
        elseif #route.Points() < 2 then
            log:Error("Less than 2 points in route '", name, "'")
            return false
        else
            log:Info("Route loaded: ", name)
        end

        if order == RouteOrder.REVERSED then
            log:Info("Reversing route '", name, "'")
            route.Reverse()
        end

        -- Find closest point within the route, or the first point, in the order the route is loaded
        local points = route.Points()
        local currentPos = Current()

        local firstIx = 1
        local nextIx = firstIx + 1

        -- Start with the distance to the first point
        local f = universe.ParsePosition(points[firstIx].Pos())

        if not f then
            log:Error("Route contains an invalid position string")
            return false
        end

        local distance = (f.Coordinates() - currentPos):Len()

        local closestIx = 0
        local nearestOnRoute ---@type Vec3|nil

        while nextIx <= #points do
            f = universe.ParsePosition(points[firstIx].Pos())
            local n = universe.ParsePosition(points[nextIx].Pos())

            if not (f and n) then
                log:Error("Route contains an invalid position string")
                return false
            end

            local onRoute = calc.NearestOnLineBetweenPoints(f.Coordinates(), n.Coordinates(), currentPos)
            local distanceToPoint = (onRoute - currentPos):Len()

            if distanceToPoint < distance then
                closestIx = firstIx
                distance = distanceToPoint
                nearestOnRoute = onRoute
            end

            firstIx = nextIx
            nextIx = nextIx + 1
        end

        if nearestOnRoute then
            log:Info("Found a point in the route that is closer than the first point, adjusting route.")
            -- The closest point is somewhere on the route so remove points before.
            for i = 1, closestIx, 1 do
                table.remove(points, 1)
            end

            -- Add a new point at the nearest point
            table.insert(points, 1, Point.New(universe.CreatePos(nearestOnRoute).AsPosString()))
        end

        -- Check we're close enough to the closest point, which is now the first one in the route.
        local firstPos = universe.ParsePosition(points[1].Pos())
        if not firstPos then return false end

        distance = (firstPos.Coordinates() - currentPos):Len()
        if not ignoreStartMargin and distance > startMargin then
            log:Error(string.format("Currently %0.2fm from closest point in route. Please move within %dm of %s and try again."
                , distance, startMargin, firstPos.AsPosString()))
            return false
        end

        current = route
        activeRouteName = name

        return true
    end

    ---Activate a temporary, empty, route
    ---@return Route
    function s.ActivateTempRoute()
        current = Route.New()
        activeRouteName = "Temporary"
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

    ---Returns the current name
    ---@return string|nil
    function s.ActiveRouteName()
        return activeRouteName
    end

    singleton = setmetatable(s, RouteController)
    return singleton
end

return RouteController
