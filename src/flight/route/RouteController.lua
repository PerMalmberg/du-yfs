local Point        = require("flight/route/Point")
local Route        = require("flight/route/Route")
local log          = require("debug/Log")()
local universe     = require("universe/Universe").Instance()
local calc         = require("util/Calc")
local PointOptions = require("flight/route/PointOptions")
local vehicle      = require("abstraction/Vehicle").New()
local pagination   = require("util/Pagination")
local Current      = vehicle.position.Current
local Forward      = vehicle.orientation.Forward
require("util/Table")

---@alias NamedWaypoint {name:string, point:Point}
---@alias WaypointMap table<string,Point>
---@alias RouteData {points:PointPOD[]}
---@alias SelectablePoint {index:number, visible:boolean, name:string}
---@module "storage/BufferedDB"

---@class RouteController
---@field GetRouteNames fun():string[]
---@field GetPageCount fun(perPage:integer):integer
---@field GetRoutePage fun(page:integer, perPage:integer):string[]
---@field LoadFloorRoute fun(name:string):Route
---@field DeleteRoute fun(name:string)
---@field StoreRoute fun(name:string, route:Route):boolean
---@field StoreWaypoint fun(name:string, pos:string):boolean
---@field GetWaypoints fun():NamedWaypoint[]
---@field LoadWaypoint fun(name:string, waypoints?:table<string,Point>):Point|nil
---@field DeleteWaypoint fun(name:string):boolean
---@field CurrentRoute fun():Route|nil
---@field CurrentEdit fun():Route|nil
---@field CurrentEditName fun():string|nil
---@field ActivateRoute fun(name:string, destinationWayPointIndex?:number, startMargin?:number):boolean
---@field ActivateTempRoute fun():Route
---@field CreateRoute fun(name:string):Route|nil
---@field ReverseRoute fun():boolean
---@field SaveRoute fun():boolean
---@field Discard fun()
---@field Count fun():integer
---@field ActiveRouteName fun():string|nil
---@field ActivateHoldRoute fun(pos:Vec3?, holdDirection:Vec3?)
---@field GetWaypointPage fun(page:integer, perPage:integer):NamedWaypoint[]
---@field GetWaypointPages fun(perPage:integer):integer
---@field FloorRoute fun():Route
---@field FloorRouteName fun():string|nil
---@field EditRoute fun(name:string):Route|nil
---@field SelectableFloorPoints fun():SelectablePoint[]

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
    local activeRouteName ---@type string|nil
    local floorRoute ---@type Route|nil
    local floorRouteName ---@type string|nil

    ---Returns the the name of all routes, with "(editing)" appended to the one currently being edited.
    ---@return string[]
    function s.GetRouteNames()
        local routes = db.Get(RouteController.NAMED_ROUTES) or {}
        local res = {} ---@type string[]
        ---@cast routes table
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
        return pagination.Paginate(s.GetRouteNames(), page, perPage)
    end

    ---@param perPage integer
    ---@return integer
    function s.GetPageCount(perPage)
        return pagination.GetPageCount(s.GetRouteNames(), perPage)
    end

    ---@param page integer
    ---@param perPage integer
    ---@return NamedWaypoint[]
    function s.GetWaypointPage(page, perPage)
        return pagination.Paginate(s.GetWaypoints(), page, perPage)
    end

    ---@param perPage integer
    ---@return integer
    function s.GetWaypointPages(perPage)
        return pagination.GetPageCount(s.GetWaypoints(), perPage)
    end

    ---Returns the number of routes
    ---@return integer
    function s.Count()
        return TableLen(s.GetRouteNames())
    end

    ---Indicates if the route exists
    ---@param name string
    ---@return boolean
    function s.routeExists(name)
        local routes = db.Get(RouteController.NAMED_ROUTES) or {}
        return routes[name] ~= nil
    end

    ---Loads a named route
    ---@param name string The name of the route to load
    ---@return Route|nil
    function s.loadRoute(name)
        local routes = db.Get(RouteController.NAMED_ROUTES) or {}
        local data = routes[name] ---@type RouteData

        if data == nil then
            log:Error("No route by name '", name, "' found.")
            return nil
        end

        local route = Route.New()

        -- For backwards compatibility, check if we have points as a sub property or not.
        -- This can be removed once all the development constructs have had their routes resaved.
        if not data.points then
            log:Warning("Route is in an old format, please re-save it!")
            data.points = data
        end

        for _, point in ipairs(data.points) do
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

    ---@return Route|nil
    function s.LoadFloorRoute(name)
        floorRoute = s.loadRoute(name)
        if s then
            floorRouteName = name
        else
            floorRouteName = nil
        end

        return floorRoute
    end

    ---@return Route|nil
    function s.FloorRoute()
        return floorRoute
    end

    ---@return string|nil
    function s.FloorRouteName()
        return floorRouteName
    end

    ---@return SelectablePoint[]
    function s.SelectableFloorPoints()
        local selectable = {}

        if floorRoute then
            for i, p in ipairs(floorRoute.Points()) do
                if p.Options().Get(PointOptions.SELECTABLE, true) then
                    selectable[#selectable + 1] = {
                        index = i,
                        visible = true,
                        name = (function()
                            if p.HasWaypointRef() then return p.WaypointRef() end
                            return "Anonymous pos."
                        end)()
                    }
                end
            end
        end

        return selectable
    end

    ---Loads a named route and makes it available for editing
    ---@param name string The name of the route to load
    ---@return Route|nil
    function s.EditRoute(name)
        if edit ~= nil then
            log:Error("A route is already being edited.")
            return nil
        end

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
        local data = { points = {} } ---@type RouteData

        for _, p in ipairs(route.Points()) do
            table.insert(data.points, p.Persist())
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

    ---Returns the name of the route currently being edited, or nil
    ---@return string|nil
    function s.CurrentEditName()
        return editName
    end

    ---@param name string
    ---@param destinationWayPointIndex number
    ---@return Route|nil
    function s.doBasicCheckesOnActivation(name, destinationWayPointIndex)
        if not name or string.len(name) == 0 then
            log:Error("No route name provided")
            return nil
        end

        if editName ~= nil and name == editName and edit ~= nil then
            log:Info("Cannot activate route currently being edited, please save first.")
            return nil
        end

        local route = s.loadRoute(name)

        if route == nil then
            return nil
        elseif #route.Points() < 2 then
            log:Error("Less than 2 points in route '", name, "'")
            return nil
        end

        if destinationWayPointIndex < 1 or destinationWayPointIndex > #route.Points() then
            log:Error("Destination index must be >= 1 and <= ", #route.Points(), " it was: ", destinationWayPointIndex)
            return nil
        end

        return route
    end

    ---Activate the route by the given name
    ---@param name string
    ---@param destinationWayPointIndex? number The index of the waypoint we wish to move to. 0 means the last one in the route. This always counts in the original order of the route.
    ---@param startMargin number? If true, the route will be activated if within this distance.
    ---@return boolean
    function s.ActivateRoute(name, destinationWayPointIndex, startMargin)
        startMargin = startMargin or 0
        local route = s.doBasicCheckesOnActivation(name, destinationWayPointIndex or 1)

        if route == nil then
            return false
        end

        destinationWayPointIndex = destinationWayPointIndex or #route.Points()
        route.AdjustRouteBasedOnTarget(Current(), destinationWayPointIndex)

        -- Find closest point within the route, or the first point, in the order the route is loaded
        local points = route.Points()
        local currentPos = Current()

        -- Check we're close enough to the closest point, which is now the first one in the route.
        local firstPos = universe.ParsePosition(points[1].Pos())
        if not firstPos then
            log:Error("Route contains an invalid position string")
            return false
        end

        if not firstPos then return false end

        local distance = (firstPos.Coordinates() - currentPos):Len()
        if startMargin > 0 and distance > startMargin then
            log:Error(string.format(
                "Currently %0.2fm from closest point in route. Please move within %0.2fm of %s and try again."
                , distance, startMargin, firstPos.AsPosString()))
            return false
        end

        current = route
        activeRouteName = name

        log:Info("Route '", name, "' activated at index " .. destinationWayPointIndex)

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

        if s.routeExists(name) then
            log:Error("Route already exists")
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

    ---Discards and currently made changes and closes the edited route
    function s.Discard()
        if edit and editName ~= nil then
            edit = nil
            editName = nil
            log:Info("All changes discarded.")
        else
            log:Error("No route currently opened for edit, nothing to discard.")
        end
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

    ---Activates a route to hold position
    ---@param pos Vec3?
    ---@param holdDirection Vec3?
    function s.ActivateHoldRoute(pos, holdDirection)
        local route = s.ActivateTempRoute()
        local p
        if pos ~= nil and holdDirection ~= nil then
            p = route.AddCoordinate(pos)
            p.Options().Set(PointOptions.LOCK_DIRECTION, { holdDirection:Unpack() })
        else
            p = route.AddCurrentPos()
            p.Options().Set(PointOptions.LOCK_DIRECTION, { Forward():Unpack() })
        end
    end

    singleton = setmetatable(s, RouteController)
    return singleton
end

return RouteController
