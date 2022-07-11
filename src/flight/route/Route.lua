--[[

    A route holds a series of Point that each contains the data needed to create a Waypoint.
    When loaded, additional points may be inserted such to create a route that is smooth to fly
    and that doesn't pass through a planetary body. Extra points are not persisted.

    Each point has the following data:
    - pos, A ::pos-string
    - waypointRef - a string naming a persisted waypoint to be loaded into the current route.
    - options - a table that holds additional options, such as max speed

]]--
local log = require("du-libs:debug/Log")()
local checks = require("du-libs:debug/Checks")
local vehicle = require("du-libs:abstraction/Vehicle")
local universe = require("du-libs:universe/Universe")()
local Point = require("flight/route/Point")

local route = {}
route.__index = route

function route:AddPos(positionString)
    checks.IsString(positionString, "positionString", "route:AddPos")

    local pos = universe:ParsePosition(positionString)

    if pos == nil then
        log:Error("Could not add position to route")
        return false
    end

    table.insert(self.points, Point(pos:AsPosString()))

    return true
end

function route:AddCoordinate(coord)
    checks.IsVec3(coord, "coord", "route:AddCoordinate")

    table.insert(self.points, Point(universe:CreatePos(coord):AsPosString()))

    return true
end

function route:AddWaypointRef(name)
    table.insert(self.points, Point("", name))
end

function route:AddPP(pp)
    table.insert(self.points, pp)
end

function route:AddCurrentPos()
    table.insert(self.points, universe:CreatePos(vehicle.position.Current()):AsPosString())
end

function route:Clear()
    self.points = {}
    self.currentPointIx = 1
end

---@return Point Returns the next point in the route or nil if it is the last.
function route:Next()
    local p = self.points[self.currentPointIx]

    if not self:LastPointReached() then
        self.currentPointIx = self.currentPointIx + 1
    end

    return p
end

function route:LastPointReached()
    return self.currentPointIx >= #self.points
end

local function new()
    local instance = {
        points = {},
        currentPointIx = 1
    }

    setmetatable(instance, route)

    return instance
end

-- The module
return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                return new(...)
            end
        }
)