local r = require("CommonRequire")
local vehicle = r.vehicle
local universe = r.universe
local calc = r.calc
local visual = r.visual
local abs = math.abs

---@alias AlignmentFunction fun(currentWaypoint:Waypoint, previous:Waypoint):Vec3

-- Reminder: Don't return a point based on the constructs' current position, it will cause spin if it overshoots etc.

-- Return a point this far from the waypoint so that in case we overshoot
-- we don't get the point behind us and start turning around
local directionMargin = 10

local alignment = {}

function alignment.NoAdjust()
    return nil
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return Vec3
function alignment.YawPitchKeepWaypointDirectionOrthogonalToVerticalReference(waypoint, previousWaypoint)
    local current = vehicle.position.Current()
    local travelDir = (waypoint.Destination() - previousWaypoint.Destination()):NormalizeInPlace()

    local nearest = calc.NearestPointOnLine(previousWaypoint.Destination(), travelDir, current)
    local point = nearest + waypoint.YawPitchDirection() * directionMargin
    visual:DrawNumber(5, point)

    return point
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return Vec3
function alignment.YawPitchKeepOrthogonalToVerticalReference(waypoint, previousWaypoint)
    local current = vehicle.position.Current()
    local normal = -universe:VerticalReferenceVector()

    local travelDir = (waypoint.Destination() - previousWaypoint.Destination()):NormalizeInPlace()

    local point = calc.NearestPointOnLine(previousWaypoint.Destination(), travelDir, current)
    local withMargin = point + travelDir * directionMargin
    visual:DrawNumber(4, withMargin)

    -- When the next waypoint is nearly above or below us, switch alignment mode.
    if abs((withMargin - current):Normalize():Dot(normal)) > 0.9 then
        local dir = alignment.TargetDirectionOrthogonalToVerticalReference()

        waypoint.LockDirection(dir, true, "vertical")
        point = waypoint.YawAndPitch(previousWaypoint)
    else
        point = calc.ProjectPointOnPlane(normal, current, withMargin)
    end

    return point
end

---@return Vec3
function alignment.TargetDirectionOrthogonalToVerticalReference()
    local current = vehicle.position.Current()
    local normal = -universe:VerticalReferenceVector()
    local alignmentPoint = calc.ProjectPointOnPlane(normal, current,
        current + vehicle.orientation.Forward() * directionMargin)
    return (alignmentPoint - current):NormalizeInPlace()
end

function alignment.RollTopsideAwayFromVerticalReference(waypoint, previousWaypoint)
    return vehicle.position.Current() - universe:VerticalReferenceVector() * directionMargin
end

return alignment
