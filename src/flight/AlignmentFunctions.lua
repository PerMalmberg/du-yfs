local r = require("CommonRequire")
local vehicle = r.vehicle
local universe = r.universe
local calc = r.calc
local abs = math.abs

---@alias AlignmentFunction fun(currentWaypoint:Waypoint, previous:Waypoint):Vec3

-- Reminder: Don't return a point based on the constructs' current position, it will cause spin if it overshoots etc.

-- Return a point this far from the waypoint so that in case we overshoot
-- we don't get the point behind us and start turning around
local directionMargin = 1000

local alignment = {}

function alignment.NoAdjust()
    return nil
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return Vec3
function alignment.YawPitchKeepWaypointDirectionOrthogonalToVerticalReference(waypoint, previousWaypoint)
    local normal = -universe:VerticalReferenceVector()
    local dir = waypoint.YawPitchDirection():ProjectOnPlane(normal)
    local nearest = calc.NearestPointOnLine(previousWaypoint.Destination(),
        (waypoint.Destination() - previousWaypoint.Destination()):NormalizeInPlace(), vehicle.position.Current())

    return nearest + dir * directionMargin
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return Vec3
function alignment.YawPitchKeepOrthogonalToVerticalReference(waypoint, previousWaypoint)
    local normal = -universe:VerticalReferenceVector()
    local nearest = calc.NearestPointOnLine(previousWaypoint.Destination(),
        (waypoint.Destination() - previousWaypoint.Destination()):NormalizeInPlace(), vehicle.position.Current())
    local dir = (waypoint.Destination() - nearest):NormalizeInPlace()

    if abs(dir:Dot(normal)) > 0.9 then
        -- When the next waypoint is nearly above or below us, switch alignment mode.
        -- This 'trick' allows turning also in manual control
        waypoint.LockDirection(vehicle.orientation.Forward(), true)
        return waypoint.YawAndPitch(previousWaypoint)
    end

    dir = dir:ProjectOnPlane(normal)
    return nearest + dir * directionMargin
end

function alignment.RollTopsideAwayFromVerticalReference(waypoint, previousWaypoint)
    return vehicle.position.Current() - universe:VerticalReferenceVector() * directionMargin
end

return alignment
