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

---@param vertRef Vec3
---@return Vec3
local function pointAtSameHeightAsConstructParallelToVerticalRef(vertRef)
    local current = Current()

    local alignmentPoint = current + vehicle.orientation.Forward() * directionMargin
    alignmentPoint = calc.ProjectPointOnPlane(vertRef, current, alignmentPoint)

    return alignmentPoint
end

---@param vertRef Vec3
---@return Vec3
local function targetDirectionOrthogonalToVerticalReference(vertRef)
    local alignmentPoint = pointAtSameHeightAsConstructParallelToVerticalRef(vertRef)
    return (alignmentPoint - Current()):NormalizeInPlace()
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return Vec3
local function getVerticalUpReference(waypoint, previousWaypoint, thresholdAngle)
    --[[
    -- When next waypoint is nearly aligned with -gravity, use the line between them as the vertical reference instead to make following the path more exact.
    local vertUp = -universe.VerticalReferenceVector()
    local pathDirection = (waypoint.Destination() - previousWaypoint.Destination()):Normalize()

    local selectedRef = vertUp
    local threshold = calc.AngleToDot(2)

    if vertUp:Dot(pathDirection) > threshold then
        selectedRef = pathDirection
    elseif vertUp:Dot(pathDirection) < -threshold then -- Don't flip upside down
        selectedRef = -pathDirection
    end
    return selectedRef]]
    return -universe.VerticalReferenceVector()
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return {yaw:Vec3, pitch:Vec3}
function alignment.YawPitchKeepLockedWaypointDirectionOrthogonalToVerticalReference(waypoint, previousWaypoint)
    local normal = getVerticalUpReference(waypoint, previousWaypoint)

    return {
        yaw = Current() + waypoint.YawPitchDirection() * directionMargin,
        pitch = pointAtSameHeightAsConstructParallelToVerticalRef(normal)
    }
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return {yaw:Vec3, pitch:Vec3}|nil
function alignment.YawPitchKeepOrthogonalToVerticalReference(waypoint, previousWaypoint)
    local current = Current()
    local normal = getVerticalUpReference(waypoint, previousWaypoint)

    local travelDir = (waypoint.Destination() - previousWaypoint.Destination()):NormalizeInPlace()

    local point = calc.NearestPointOnLine(previousWaypoint.Destination(), travelDir, current)
    local withMargin = point + travelDir * directionMargin

    local res = {} ---@type {yaw:Vec3, pitch:Vec3}|nil

    -- When the next waypoint is nearly above or below us, switch alignment mode.
    if abs((withMargin - current):Normalize():Dot(normal)) > 0.9 then
        local dir = targetDirectionOrthogonalToVerticalReference(normal)

        waypoint.LockDirection(dir, true)
        res = waypoint.YawAndPitch(previousWaypoint)
    else
        res.yaw = calc.ProjectPointOnPlane(normal, current, withMargin)
        res.pitch = pointAtSameHeightAsConstructParallelToVerticalRef(normal)
    end

    return res
end

---@param waypoint Waypoint
---@param previousWaypoint Waypoint
---@return Vec3
function alignment.RollTopsideAwayFromVerticalReference(waypoint, previousWaypoint)
    local normal = -universe.VerticalReferenceVector()
    -- When next waypoint is nearly above us, use the line between them as the vertical reference instead to make following the path more exact
    local wpNormal = (waypoint.Destination() - previousWaypoint.Destination()):Normalize()
    if not waypoint.WithinMargin(WPReachMode.ENTRY) and normal:Dot(wpNormal) > 0.8 then
        normal = wpNormal
    end

    return Current() + normal * directionMargin
end

---@param previous Waypoint
---@param next Waypoint
---@return Vec3 direction The direction from `previous` to `next` projected on the current plane
function alignment.DirectionBetweenWaypointsOrthogonalToVerticalRef(next, previous)
    local current = Current()
    local normal = -universe.VerticalReferenceVector()
    local p = calc.ProjectPointOnPlane(normal, current, previous.Destination())
    local n = calc.ProjectPointOnPlane(normal, current, next.Destination())
    return (n - p):NormalizeInPlace()
end

return alignment
