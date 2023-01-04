local r = require("CommonRequire")
local vehicle = r.vehicle
local universe = r.universe
local calc = r.calc
local Current = vehicle.position.Current
local abs = math.abs

---@alias AlignmentFunction fun(currentWaypoint:Waypoint, previous:Waypoint):{yaw:Vec3, pitch:Vec3}

-- Reminder: Don't return a point based on the constructs' current position, it will cause spin if it overshoots etc.
local alignment = {}

-- Return a direction target point this far from the waypoint so that in case we overshoot
-- we don't get the point behind us and start turning around and also reduces oscilliating yaw.
alignment.DirectionMargin = 1000


function alignment.NoAdjust()
    return nil
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return {yaw:Vec3, pitch:Vec3}
function alignment.YawPitchKeepWaypointDirectionOrthogonalToVerticalReference(waypoint, previousWaypoint)
    local current = Current()
    local travelDir = (waypoint.Destination() - previousWaypoint.Destination()):NormalizeInPlace()

    local nearest = calc.NearestPointOnLine(previousWaypoint.Destination(), travelDir, current)
    local point = nearest + waypoint.YawPitchDirection() * DirectionMargin

    return { yaw = point,
        pitch = alignment.PointAtSameHeightAsConstructParallelToVerticalRef() }
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return {yaw:Vec3, pitch:Vec3}|nil
function alignment.YawPitchKeepOrthogonalToVerticalReference(waypoint, previousWaypoint)
    local current = Current()
    local normal = -universe:VerticalReferenceVector()

    local travelDir = (waypoint.Destination() - previousWaypoint.Destination()):NormalizeInPlace()

    local point = calc.NearestPointOnLine(previousWaypoint.Destination(), travelDir, current)
    local withMargin = point + travelDir * DirectionMargin

    local res = {} ---@type {yaw:Vec3, pitch:Vec3}|nil

    -- When the next waypoint is nearly above or below us, switch alignment mode.
    if abs((withMargin - current):Normalize():Dot(normal)) > 0.9 then
        local dir = alignment.TargetDirectionOrthogonalToVerticalReference()

        waypoint.LockDirection(dir, true)
        res = waypoint.YawAndPitch(previousWaypoint)
    else
        res.yaw = calc.ProjectPointOnPlane(normal, current, withMargin)
        res.pitch = alignment.PointAtSameHeightAsConstructParallelToVerticalRef()
    end

    return res
end

function alignment.RollTopsideAwayFromVerticalReference(waypoint, previousWaypoint)
    return Current() - universe:VerticalReferenceVector() * DirectionMargin
end

---@return Vec3
function alignment.TargetDirectionOrthogonalToVerticalReference()
    local alignmentPoint = alignment.PointAtSameHeightAsConstructParallelToVerticalRef()
    return (alignmentPoint - Current()):NormalizeInPlace()
end

---@return Vec3
function alignment.PointAtSameHeightAsConstructParallelToVerticalRef()
    local current = Current()
    local normal = -universe:VerticalReferenceVector()

    local alignmentPoint = current + vehicle.orientation.Forward() * DirectionMargin
    alignmentPoint = calc.ProjectPointOnPlane(normal, current, alignmentPoint)

    return alignmentPoint
end

return alignment
