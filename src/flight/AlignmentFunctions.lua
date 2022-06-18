local construct = require("du-libs:abstraction/Construct")()
local universe = require("du-libs:universe/Universe")()
local abs = math.abs

local alignment = {}

function alignment.YawPitchKeepWaypointDirectionOrthogonalToGravity(waypoint, _)
    local normal = -construct.world.GAlongGravity():normalize_inplace()
    local dir = waypoint.yawPitchDirection:project_on_plane(normal)
    return construct.position.Current() + dir * 10
end

function alignment.YawPitchKeepOrthogonalToGravity(waypoint, previousWaypoint)
    local normal = -construct.world.GAlongGravity():normalize_inplace()
    local dir = (waypoint.destination - construct.position.Current()):normalize_inplace()

    if abs(dir:dot(normal)) > 0.9 then
        -- When the next waypoint is nearly above or below us, switch alignment mode.
        -- This 'trick' allows turning also in manual control
        waypoint:OneTimeSetYawPitchDirection(construct.orientation.Forward(), alignment.YawPitchKeepWaypointDirectionOrthogonalToGravity)
        return nil
    end

    dir = dir:project_on_plane(normal)
    return construct.position.Current() + dir * 10
end

function alignment.RollTopsideAwayFromNearestBody(waypoint, previousWaypoint)
    local center = universe:ClosestBody().Geography.Center
    local pos = construct.position.Current()
    return pos + (pos - center):normalize_inplace() * 100
end

function alignment.RollTopsideAwayFromGravity(waypoint, previousWaypoint)
    -- Presumably we have gravity near a space construct too so we want to align based on that.
    if construct.world.G() > 0 then
        return construct.position.Current() - construct.world.GAlongGravity():normalize() * 100
    else
        return nil -- Don't do alignment in space
    end
end

return alignment