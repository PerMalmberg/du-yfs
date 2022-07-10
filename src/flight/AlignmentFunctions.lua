local vehicle = require("du-libs:abstraction/Vehicle")()
local universe = require("du-libs:universe/Universe")()
local calc = require("du-libs:util/Calc")
local abs = math.abs

-- Reminder: Don't return a point based on the constructs' current position, it will cause spin if it overshoots etc.

-- Return a point this far from the waypoint so that in case we overshoot
-- we don't get the point behind us and start turning around
local directionMargin = 1000

local alignment = {}

function alignment.NoAdjust()
    return nil
end

function alignment.YawPitchKeepWaypointDirectionOrthogonalToVerticalReference(waypoint, previousWaypoint)
    local normal = -universe:VerticalReferenceVector()
    local dir = waypoint.yawPitchDirection:project_on_plane(normal)
    local nearest = calc.NearestPointOnLine(previousWaypoint.destination, (waypoint.destination - previousWaypoint.destination):normalize_inplace(), vehicle.position.Current())

    return nearest + dir * directionMargin
end

function alignment.YawPitchKeepOrthogonalToVerticalReference(waypoint, previousWaypoint)
    local normal = -universe:VerticalReferenceVector()
    local nearest = calc.NearestPointOnLine(previousWaypoint.destination, (waypoint.destination - previousWaypoint.destination):normalize_inplace(), vehicle.position.Current())
    local dir = (waypoint.destination - nearest):normalize_inplace()

    if abs(dir:dot(normal)) > 0.9 then
        -- When the next waypoint is nearly above or below us, switch alignment mode.
        -- This 'trick' allows turning also in manual control
        local f = alignment.YawPitchKeepWaypointDirectionOrthogonalToVerticalReference
        waypoint:OneTimeSetYawPitchDirection(vehicle.orientation.Forward(), f)
        return f(waypoint, previousWaypoint)
    end

    dir = dir:project_on_plane(normal)
    return nearest + dir * directionMargin
end

function alignment.RollTopsideAwayFromVerticalReference(waypoint, previousWaypoint)
    return vehicle.position.Current() - universe:VerticalReferenceVector() * directionMargin
end

return alignment