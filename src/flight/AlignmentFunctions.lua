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
local directionMargin = 1000
alignment.DirectionMargin = directionMargin


function alignment.NoAdjust()
    return nil
end

---@return Vec3
local function pointAtSameHeightAsConstructParallelToVerticalRef()
    local current = Current()
    local normal = -universe.VerticalReferenceVector()

    local alignmentPoint = current + vehicle.orientation.Forward() * directionMargin
    alignmentPoint = calc.ProjectPointOnPlane(normal, current, alignmentPoint)

    return alignmentPoint
end

---@return Vec3
local function targetDirectionOrthogonalToVerticalReference()
    local alignmentPoint = pointAtSameHeightAsConstructParallelToVerticalRef()
    return (alignmentPoint - Current()):NormalizeInPlace()
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return {yaw:Vec3, pitch:Vec3}
function alignment.YawPitchKeepLockedWaypointDirectionOrthogonalToVerticalReference(waypoint, previousWaypoint)
    return {
        yaw = Current() + waypoint.YawPitchDirection() * directionMargin,
        pitch = pointAtSameHeightAsConstructParallelToVerticalRef()
    }
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return {yaw:Vec3, pitch:Vec3}|nil
function alignment.YawPitchKeepOrthogonalToVerticalReference(waypoint, previousWaypoint)
    local current = Current()
    local normal = -universe:VerticalReferenceVector()

    local travelDir = (waypoint.Destination() - previousWaypoint.Destination()):NormalizeInPlace()

    local point = calc.NearestPointOnLine(previousWaypoint.Destination(), travelDir, current)
    local withMargin = point + travelDir * directionMargin

    local res = {} ---@type {yaw:Vec3, pitch:Vec3}|nil

    -- When the next waypoint is nearly above or below us, switch alignment mode.
    if abs((withMargin - current):Normalize():Dot(normal)) > 0.9 then
        local dir = targetDirectionOrthogonalToVerticalReference()

        waypoint.LockDirection(dir, true)
        res = waypoint.YawAndPitch(previousWaypoint)
    else
        res.yaw = calc.ProjectPointOnPlane(normal, current, withMargin)
        res.pitch = pointAtSameHeightAsConstructParallelToVerticalRef()
    end

    return res
end

function alignment.RollTopsideAwayFromVerticalReference(waypoint, previousWaypoint)
    return Current() - universe.VerticalReferenceVector() * directionMargin
end

---@param previous Waypoint
---@param next Waypoint
---@return Vec3 direction The direction from `previous` to `next` projected on the current plane
function alignment.DirectionBetweenWaypointsOrthogonalToVerticalRef(previous, next)
    local current = Current()
    local normal = -universe.VerticalReferenceVector()
    local p = calc.ProjectPointOnPlane(normal, current, previous.Destination())
    local c = calc.ProjectPointOnPlane(normal, current, next.Destination())
    return (p - c):NormalizeInPlace()
end

return alignment
