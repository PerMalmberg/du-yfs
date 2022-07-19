--[[
    A route holds a series of Point that each contains the data needed to create a Waypoint.
    When loaded, additional points may be inserted to to create a route that is smooth to fly
    and that doesn't pass through a planetary body. Extra points are not persisted.
]]--
local log = require("du-libs:debug/Log")()
local checks = require("du-libs:debug/Checks")
local vehicle = require("du-libs:abstraction/Vehicle")()
local universe = require("du-libs:universe/Universe")()
local Point = require("flight/route/Point")

local route = {}
route.__index = route

function route:AddPos(positionString)
    checks.IsString(positionString, "positionString", "route:AddPos")

    local pos = universe:ParsePosition(positionString)

    if pos == nil then
        log:Error("Could not add position to route")
        return nil
    end

    return self:AddPoint(Point(pos:AsPosString()))
end

function route:AddCoordinate(coord)
    checks.IsVec3(coord, "coord", "route:AddCoordinate")

    return self:AddPoint(Point(universe:CreatePos(coord):AsPosString()))
end

function route:AddWaypointRef(name)
    return self:AddPoint(Point("", name))
end

function route:AddCurrentPos()
    return self:AddCoordinate(vehicle.position.Current())
end

function route:AddPoint(point)
    table.insert(self.points, point)
    return point
end

function route:Clear()
    self.points = {}
    self.currentPointIx = 1
end

---@return Point Returns the next point in the route or nil if it is the last.
function route:Next()
    if self:LastPointReached() then
        return nil
    end

    local p = self.points[self.currentPointIx]
    self.currentPointIx = self.currentPointIx + 1

    return p
end

function route:Dump()
    for _, p in ipairs(self.points) do
        log:Info(p:Persist())
    end
end

function route:LastPointReached()
    return self.currentPointIx > #self.points
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