local construct = require("du-libs:abstraction/Construct")()
local universe = require("du-libs:universe/Universe")()
local calc = require("du-libs:util/Calc")
local abs = math.abs

-- Reminder: Don't return a point based on the constructs' current position, it will cause spin if it overshoots etc.

-- Return a point this far from the waypoint so that in case we overshoot
-- we don't get the point behind us and start turning around
local directionMargin = 1000

local alignment = {}

function alignment.YawPitchKeepWaypointDirectionOrthogonalToGravity(waypoint, previousWaypoint)
    local normal = -construct.world.GAlongGravity():normalize_inplace()
    local dir = waypoint.yawPitchDirection:project_on_plane(normal)
    local nearest = calc.NearestPointOnLine(previousWaypoint.destination, (waypoint.destination - previousWaypoint.destination):normalize_inplace(), construct.position.Current())

    return nearest + dir * directionMargin
end

function alignment.YawPitchKeepOrthogonalToGravity(waypoint, previousWaypoint)
    local normal = -construct.world.GAlongGravity():normalize_inplace()
    local nearest = calc.NearestPointOnLine(previousWaypoint.destination, (waypoint.destination - previousWaypoint.destination):normalize_inplace(), construct.position.Current())
    local dir = (waypoint.destination - nearest):normalize_inplace()

    if abs(dir:dot(normal)) > 0.9 then
        -- When the next waypoint is nearly above or below us, switch alignment mode.
        -- This 'trick' allows turning also in manual control
        local f = alignment.YawPitchKeepWaypointDirectionOrthogonalToGravity
        waypoint:OneTimeSetYawPitchDirection(construct.orientation.Forward(), f)
        return f(waypoint, previousWaypoint)
    end

    dir = dir:project_on_plane(normal)
    return nearest + dir * directionMargin
end

function alignment.RollTopsideAwayFromNearestBody(waypoint, previousWaypoint)
    local center = universe:ClosestBody().Geography.Center
    local pos = construct.position.Current()
    return pos + (pos - center):normalize_inplace() * directionMargin
end

function alignment.RollTopsideAwayFromGravity(waypoint, previousWaypoint)
    -- Presumably we have gravity near a space construct too so we want to align based on that.
    if construct.world.G() > 0 then
        return construct.position.Current() - construct.world.GAlongGravity():normalize() * directionMargin
    else
        return nil -- Don't do alignment in space
    end
end

return alignment