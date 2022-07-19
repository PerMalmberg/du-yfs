local Point = require("flight/route/Point")
local PointOptions = require("flight/route/PointOptions")
local Route = require("flight/route/Route")
local log = require("du-libs:debug/Log")()

local controller = {}
controller.__index = controller

local NAMED_POINTS = "NamedPoints"
local NAMED_ROUTES = "NamedRoutes"

function controller:GetRouteNames()
    local routes = self.db:Get(NAMED_ROUTES) or {}
    local res = {}
    for name, _ in pairs(routes) do
        if name == self.editName then
            name = name .. " (editing)"
        end
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

    for _, point in ipairs(data) do
        local p = Point(point.pos, point.waypointRef, PointOptions:New(point.options))

        if p:HasWaypointRef() then
            local wpName = p:WaypointRef()
            log:Debug("Loading waypoint reference '", wpName, "'")
            local wp = self:LoadWaypoint(wpName)
            if wp == nil then
                log:Error("The referenced waypoint '", wpName, "' was not found")
                return nil
            end

            p.pos = wp.pos
        end

        route:AddPoint(p)
    end

    self.edit = route
    self.editName = name

    log:Info("Route '", name, "' loaded")
    return route
end

function controller:DeleteRoute(name)
    local routes = self.db:Get(NAMED_ROUTES) or {}
    local route = routes[name]

    if route == nil then
        log:Error("No route by name '", name, "' found.")
        return nil
    end

    routes[name] = nil
    self.db:Put(NAMED_ROUTES, routes)
    log:Info("Route '", name, "' deleted")

    if name == self.editName then
        self.edit = nil
        self.editName = nil
        log:Info("No route is currently being edited")
    end
end

---@param name string The name to store the route as
---@param route Route The route to store
function controller:StoreRoute(name, route)
    if not self.edit then
        log:Error("Cannot save, no route currently being edited")
        return
    end

    local routes = self.db:Get(NAMED_ROUTES) or {}
    local data = {}

    for _, p in ipairs(route.points) do
        table.insert(data, p:Persist())
    end

    routes[name] = data
    self.db:Put(NAMED_ROUTES, routes)
    log:Info("Route '", name, "' saved.")
end

---@param name string The name of the waypoint
---@param pos string A ::pos string
function controller:StoreWaypoint(name, pos, options)
    local waypoints = self.db:Get(NAMED_POINTS) or {}
    local p = Point(pos)
    waypoints[name] = p:Persist()

    self.db:Put(NAMED_POINTS, waypoints)
    log:Info("Waypoint saved as '", name, "'")
end

function controller:LoadWaypoint(name)
    local waypoints = self.db:Get(NAMED_POINTS) or {}
    local point = waypoints[name]

    if point == nil then
        log:Error("No waypoint by name '", name, "' found.")
        return nil
    end

    return Point(point.pos)
end

---@return Point Returns the next point in the route or nil if it is the last.
function controller:CurrentRoute()
    return self.current
end

function controller:CurrentEdit()
    return self.edit
end

function controller:ActivateRoute(name)
    if name == nil then
        self.current = Route()
        return false
    end

    if name == self.editName then
        log:Info("Activating route currently being edited, forcing save.")
        self:StoreRoute(self.editName, self.edit)
    end

    local r = self:LoadRoute(name)

    if r ~= nil then
        self.current = r
        log:Info("Route activated: ", name)
    end

    return true
end

function controller:CreateRoute(name)
    if name == nil or #name == 0 then
        log:Error("No name provided for route")
        return false
    end

    self.edit = Route()
    self.editName = name

    log:Info("Route '", name, "' created (but not yet saved)")
    return true
end

function controller:SaveRoute()
    if self.edit then
        self:StoreRoute(self.editName, self.edit)
    else
        log:Error("No route currently opened for edit.")
    end
end

local function new(bufferedDB)
    local instance = {
        db = bufferedDB,
        current = nil,
        edit = nil,
        editName = nil
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