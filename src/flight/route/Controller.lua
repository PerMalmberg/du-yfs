local Point = require("flight/route/Point")
local Route = require("flight/route/Route")
local log = require("du-libs:debug/Log")()

local controller = {}
controller.__index = controller

local NAMED_POINTS = "NamedPoints"
local NAMED_ROUTES = "NamedRoutes"
local DEFAULT_ROUTE = "DefaultRoute"

function controller:GetRouteNames()
    local routes = self.db:Get(NAMED_ROUTES) or {}
    local res = {}
    for _, name in ipairs(routes) do
        table.insert(res, name)
    end

    return res
end

---@param name string The name of the route to load
---@return Route A route or nil on failure
function controller:LoadRoute(name)
    local routes = self.db:Get(NAMED_ROUTES) or {}
    local data = routes[name]

    if data == nil then
        log:Error("No route by name '", name, "' found.")
        return nil
    end

    local route = Route()

    for _, point in ipairs(route) do
        local pp = Point(point.pos, point.waypointRef, point.options)

        if pp:HasWaypointRef() then
            local wpName = pp:WaypointRef()
            log:Debug("Loading waypoint reference '", wpName, "'")
            pp = self:LoadWaypoint(wpName)
            if pp == nil then
                log:Error("The waypoint by name '", wpName, "' was not found")
                return nil
            end
        end

        route.AddPP(pp)
    end

    return route
end

function controller:DeleteRoute(name)
    if name == DEFAULT_ROUTE then
        log:Error("Cannot delete the default route")
        return
    end

    local routes = self.db:Get(NAMED_ROUTES) or {}
    local route = routes[name]

    if route == nil then
        log:Error("No route by name '", name, "' found.")
        return nil
    end

    routes[name] = nil
    self.db.Put(NAMED_ROUTES, routes)
end

---@param name string The name to store the route as
---@param route Route The route to store
function controller:StoreRoute(name, route)
    if name == DEFAULT_ROUTE then
        log:Error("Cannot store route with the default name")
        return
    end

    local routes = self.db:Get(NAMED_ROUTES) or {}
    local data = {}
    routes[name] = data

    for _, point in ipairs(route.points) do
        table.insert(data, point:Persist())
    end

    self.db:Put(NAMED_ROUTES, routes)
end

---@param name string The name of the waypoint
---@param pos string A ::pos string
function controller:StoreWaypoint(name, pos, options)
    local waypoints = self.db:Get(NAMED_POINTS) or {}
    local p = Point(pos)
    p.options = options or {}
    waypoints[name] = p

    self.db.Put(NAMED_POINTS, waypoints)
end

function controller:LoadWaypoint(name)
    local waypoints = self.db:Get(NAMED_POINTS) or {}
    local point = waypoints[name]

    if point == nil then
        log:Error("No waypoint by name '", name, "' found.")
        return nil
    end

    return Point(point.pos,
            "", -- A waypoint can never refer to another point
            point.options)
end

---@return Point Returns the next point in the route or nil if it is the last.
function controller:CurrentRoute()
    return self.current
end

function controller:ActivateRoute(name)
    if name == nil then
        self.current = Route()
        self.currentName = DEFAULT_ROUTE
    else
        self.current = self:LoadRoute(name)

        if self.current == nil then
            log:Error("Route activation failed, falling back to default route")
            self.currentName = DEFAULT_ROUTE
        else
            log:Info("Route activated: ", name)
            self.currentName = name
        end
    end
end

function controller:CreateRoute(name)
    if name == nil or #name == 0 then
        log:Error("No name provided for route")
        return false
    end

    self.current = Route()
    self.currentName = name

    return true
end

function controller:SaveCurrentRoute()
    if self.currentName ~= DEFAULT_ROUTE then
        log:Info("Storing current route: ", self.currentName)
        self:StoreRoute(self.currentName, self.current)
    end
end

local function new(bufferedDB)
    local instance = {
        db = bufferedDB,
        current = nil,
        currentName = DEFAULT_ROUTE
    }

    setmetatable(instance, controller)

    return instance
end

local singleton

-- The module
return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                if singleton == nil then
                    singleton = new(...)
                end

                return singleton
            end
        }
)