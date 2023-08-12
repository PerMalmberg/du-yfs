local Point          = require("flight/route/Point")
local Route          = require("flight/route/Route")
local Task           = require("system/Task")
local log            = require("debug/Log").Instance()
local universe       = require("universe/Universe").Instance()
local pub            = require("util/PubSub").Instance()
local PointOptions   = require("flight/route/PointOptions")
local vehicle        = require("abstraction/Vehicle").New()
local pagination     = require("util/Pagination")
local distanceFormat = require("util/DistanceFormat")
local Current        = vehicle.position.Current
local Forward        = vehicle.orientation.Forward
require("util/Table")

---@alias NamedWaypoint {name:string, point:Point}
---@alias WaypointMap table<string,PointPOD>
---@alias RouteData {points:PointPOD[], gateControl:{waitAtStart:boolean, waitAtEnd:boolean}}
---@alias SelectablePoint {visible:boolean, name:string, activate:string, index:number}
---@module "storage/BufferedDB"

---@class RouteController
---@field GetRouteNames fun():string[]
---@field GetPageCount fun(perPage:integer):integer
---@field GetRoutePage fun(page:integer, perPage:integer):string[]
---@field LoadRoute fun(name:string):Route|nil
---@field LoadFloorRoute fun(name:string):Route
---@field DeleteRoute fun(name:string)
---@field StoreRoute fun(name:string, route:Route):boolean
---@field RenameRoute fun(from:string, to:string)
---@field StoreWaypoint fun(name:string, pos:string):boolean
---@field GetWaypoints fun():NamedWaypoint[]
---@field LoadWaypoint fun(name:string, waypoints?:table<string,Point>):Point|nil
---@field DeleteWaypoint fun(name:string):PointPOD|nil
---@field CurrentRoute fun():Route|nil
---@field CurrentEdit fun():Route|nil
---@field CurrentEditName fun():string|nil
---@field ActivateRoute fun(name:string, destinationWayPointIndex?:number, startMargin?:number, openGateMaxDistance?:number):boolean
---@field ActivateTempRoute fun():Route
---@field CreateRoute fun(name:string):Route|nil
---@field SaveRoute fun():boolean
---@field Discard fun()
---@field Count fun():integer
---@field ActiveRouteName fun():string|nil
---@field ActivateHoldRoute fun()
---@field GetWaypointPage fun(page:integer, perPage:integer):NamedWaypoint[]
---@field GetWaypointPages fun(perPage:integer):integer
---@field FloorRoute fun():Route
---@field FloorRouteName fun():string|nil
---@field EditRoute fun(name:string):Route|nil
---@field SelectableFloorPoints fun():SelectablePoint[]
---@field CalculateDistances fun(points:Point[]):number[]
---@field FirstFreeWPName fun():string|nil
---@field RenameWaypoint fun(old:string, new:string):boolean

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

    ---@return table<string, NamedWaypoint>
    local function makeWPLookup()
        -- Make a table for quick lookup
        local wps = {}
        for _, p in ipairs(s.GetWaypoints()) do
            wps[p.name] = p
        end

        return wps
    end

    ---@return string|nil
    function s.FirstFreeWPName()
        local wps = makeWPLookup()

        for i = 1, 999 do
            local new = string.format("WP%0.3d", i)
            if wps[new] == nil then
                return new
            end
        end

        return nil
    end

    ---@param old string
    ---@param new string
    function s.RenameWaypoint(old, new)
        local wps = makeWPLookup()
        local oldFound = wps[old]
        local newFound = wps[new]

        if not oldFound then
            log.Info("No waypoint by that name found")
            return
        elseif newFound then
            log.Info("A waypoint by that name already exists")
        end

        Task.New("RenameWaypoint", function()
            if edit ~= nil then
                log.Error("Can't rename a waypoint when a route is being edited")
                return
            end

            s.StoreWaypoint(new, oldFound.point:Pos())

            for _, name in pairs(s.GetRouteNames()) do
                local r = s.LoadRoute(name)
                if r then
                    local switched = false
                    for _, p in ipairs(r.Points()) do
                        if p.HasWaypointRef() and p.WaypointRef() == old then
                            switched = true
                            p.SetWaypointRef(new)
                            log.Info("Waypoint ref. updated in route '", name, "': '", old, "' -> '", new, "'")
                        end
                    end

                    if switched then
                        s.StoreRoute(name, r)
                    end
                end
                coroutine.yield()
            end

            -- Delete last so that routes using it can be loaded.
            s.DeleteWaypoint(old)
        end)
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
    function s.LoadRoute(name)
        local routes = db.Get(RouteController.NAMED_ROUTES) or {}
        local data = routes[name] ---@type RouteData

        if data == nil then
            log.Error("No route by name '", name, "' found.")
            return nil
        end

        local route = Route.New()

        -- For backwards compatibility, check if we have points as a sub property or not.
        -- This can be removed once all the development constructs have had their routes resaved.
        if not data.points then
            log.Warning("Route is in an old format, please re-save it!")
            data.points = data
        end

        for _, point in ipairs(data.points) do
            local p = Point.LoadFromPOD(point)

            if p.HasWaypointRef() then
                local wpName = p.WaypointRef()
                log.Debug("Loading waypoint reference '", wpName, "'")
                local wp = s.LoadWaypoint(wpName)
                if wp == nil then
                    log.Error("The referenced waypoint '", wpName, "' in route '", name, "' was not found")
                    return nil
                end

                -- Replace the point
                p = Point.New(wp.Pos(), wpName, p.Options())
            end

            route.AddPoint(p)
        end

        log.Info("Route '", name, "' loaded")

        return route
    end

    ---@return Route|nil
    function s.LoadFloorRoute(name)
        floorRoute = s.LoadRoute(name)
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
        local selectable = {} ---@type SelectablePoint[]

        if floorRoute then
            local points = floorRoute.Points()
            local distances = s.CalculateDistances(points)
            for i, p in ipairs(points) do
                if p.Options().Get(PointOptions.SELECTABLE, true) then
                    selectable[#selectable + 1] = {
                        visible = true,
                        name = (function()
                            if p.HasWaypointRef() then
                                -- Silence warning of string vs. nil, we've already checked if it has a waypoint reference
                                return p.WaypointRef() or ""
                            end
                            local d = distanceFormat(distances[i])
                            return string.format("%0.1f%s", d.value, d.unit)
                        end)(),
                        activate = string.format("route-activate %s -index %d", floorRouteName, i),
                        index = i
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
            log.Error("A route is already being edited.")
            return nil
        end

        edit = s.LoadRoute(name)

        if edit == nil then return end
        editName = name

        pub.Publish("RouteOpenedForEdit", true)

        return edit
    end

    ---Deletes the named route
    ---@param name string
    function s.DeleteRoute(name)
        local routes = db.Get(RouteController.NAMED_ROUTES) or {}
        local route = routes[name]

        if route == nil then
            log.Error("No route by name '", name, "' found.")
            return
        end

        routes[name] = nil
        db.Put(RouteController.NAMED_ROUTES, routes)
        log.Info("Route '", name, "' deleted")

        if name == editName then
            edit = nil
            editName = nil
            log.Info("No route is currently being edited")
        end
    end

    ---Store the route under the given name
    ---@param name string The name to store the route as
    ---@param route Route The route to store
    ---@return boolean
    function s.StoreRoute(name, route)
        local routes = db.Get(RouteController.NAMED_ROUTES) or {}
        local data = { points = {} } ---@type RouteData

        for _, p in ipairs(route.Points()) do
            data.points[#data.points + 1] = p.Persist()
        end

        routes[name] = data
        db.Put(RouteController.NAMED_ROUTES, routes)
        log.Info("Route '", name, "' saved.")
        return true
    end

    ---@param from string
    ---@param to string
    function s.RenameRoute(from, to)
        if s.routeExists(to) then
            log.Error("Route already exists")
        else
            local r = s.LoadRoute(from)
            if r then
                s.StoreRoute(to, r)
                s.DeleteRoute(from)
                log.Info("Route renamed from ", from, " to ", to)
                return true
            end
        end

        return false
    end

    ---Stores a waypoint under the given name
    ---@param name string The name of the waypoint
    ---@param pos string A ::pos string
    ---@return boolean
    function s.StoreWaypoint(name, pos)
        local p = universe.ParsePosition(pos)
        if p == nil then return false end

        if name == nil or string.len(name) == 0 then
            log.Error("No name provided")
            return false
        end

        local waypoints = db.Get(RouteController.NAMED_POINTS) or {}
        waypoints[name] = Point.New(pos).Persist()

        db.Put(RouteController.NAMED_POINTS, waypoints)
        log.Info("Waypoint saved as '", name, "'")
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
    ---@return PointPOD|nil #The removed point
    function s.DeleteWaypoint(name)
        local waypoints = getNamedPoints()
        local found = waypoints[name]
        if found then
            waypoints[name] = nil
            db.Put(RouteController.NAMED_POINTS, waypoints)
        else
            log.Error("No waypoint by name '", name, "' found.")
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
            log.Error("No route name provided")
            return nil
        end

        if editName ~= nil and name == editName and edit ~= nil then
            log.Info("Cannot activate route currently being edited, please save first.")
            return nil
        end

        local route = s.LoadRoute(name)

        if route == nil then
            return nil
        elseif #route.Points() < 2 then
            log.Error("Less than 2 points in route '", name, "'")
            return nil
        end

        if destinationWayPointIndex < 1 or destinationWayPointIndex > #route.Points() then
            log.Error("Destination index must be >= 1 and <= ", #route.Points(), " it was: ", destinationWayPointIndex)
            return nil
        end

        return route
    end

    ---Activate the route by the given name
    ---@param name string
    ---@param destinationWayPointIndex? number The index of the waypoint we wish to move to. 0 means the last one in the route. This always counts in the original order of the route.
    ---@param startMargin? number The route will only be activated if within this distance.
    ---@param openGateMaxDistance? number Gate control will only be activated if this close to a controlled point in the route
    ---@return boolean
    function s.ActivateRoute(name, destinationWayPointIndex, startMargin, openGateMaxDistance)
        startMargin = startMargin or 0
        openGateMaxDistance = openGateMaxDistance or 10
        local candidate = s.doBasicCheckesOnActivation(name, destinationWayPointIndex or 1)

        if candidate == nil then
            return false
        end

        local currentPos = Current()
        destinationWayPointIndex = destinationWayPointIndex or #candidate.Points()
        candidate.AdjustRouteBasedOnTarget(currentPos, destinationWayPointIndex, openGateMaxDistance)

        -- Check we're close enough to the closest point
        local closestPosInRoute = candidate.FindClosestPositionAlongRoute(currentPos)

        local distance = closestPosInRoute:Dist(currentPos)
        if startMargin > 0 and distance > startMargin then
            log.Error(string.format(
                "Currently %0.2fm from closest point in route. Please move within %0.2fm of %s and try again."
                , distance, startMargin, universe.CreatePos(closestPosInRoute):AsPosString()))
            return false
        end

        current = candidate
        activeRouteName = name

        log.Info("Route '", name, "' activated at index " .. destinationWayPointIndex)

        return true
    end

    ---Activate a temporary, empty, route
    ---@return Route
    function s.ActivateTempRoute()
        current = Route.New()
        activeRouteName = "---"
        return current
    end

    ---Creates a route
    ---@param name string
    ---@return Route|nil
    function s.CreateRoute(name)
        if edit ~= nil then
            log.Error("A route is being edited, can't create a new one.")
            return nil
        end

        if name == nil or #name == 0 then
            log.Error("No name provided for route")
            return nil
        end

        if s.routeExists(name) then
            log.Error("Route already exists")
            return nil
        end

        edit = Route.New()
        editName = name
        s.SaveRoute()

        log.Info("Route '", name, "' created")
        edit = s.EditRoute(name)
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
            log.Info("Route saved")
            res = true
        else
            log.Error("No route currently opened for edit.")
        end

        return res
    end

    ---Discards and currently made changes and closes the edited route
    function s.Discard()
        if edit and editName ~= nil then
            edit = nil
            editName = nil
            log.Info("All changes discarded.")
        else
            log.Error("No route currently opened for edit, nothing to discard.")
        end
    end

    ---Returns the current name
    ---@return string|nil
    function s.ActiveRouteName()
        return activeRouteName
    end

    ---Activates a route to hold position
    function s.ActivateHoldRoute()
        local route = s.ActivateTempRoute()
        local p = route.AddCurrentPos()
        local opt = p.Options()
        opt.Set(PointOptions.LOCK_DIRECTION, { Forward():Unpack() })
        opt.Set(PointOptions.FORCE_VERT, true)
    end

    ---Returns a list of point distances
    ---@param points Point[]
    function s.CalculateDistances(points)
        local d = {}

        if #points > 0 then
            local prev = universe.ParsePosition(points[1].Pos()):Coordinates()
            d[#d + 1] = 0
            for i = 2, #points do
                local curr = universe.ParsePosition(points[i].Pos()):Coordinates()
                local diff = (curr - prev):Len()
                d[#d + 1] = d[#d] + diff
                prev = curr
            end
        end

        return d
    end

    singleton = setmetatable(s, RouteController)
    return singleton
end

return RouteController
