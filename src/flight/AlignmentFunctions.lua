local construct = require("du-libs:abstraction/Construct")()
local universe = require("du-libs:universe/Universe")()

local alignment = {}

function alignment.YawPitchKeepWaypointDirectionOrthogonalToGravity(waypoint, _)
    local dir = waypoint.yawPitchDirection:project_on_plane(-construct.world.GAlongGravity():normalize_inplace())
    return construct.position.Current() + dir * 10
end

function alignment.YawPitchKeepOrthogonalToGravity(waypoint, previousWaypoint)
    local dir = (waypoint.destination - construct.position.Current()):normalize_inplace()
    dir = dir:project_on_plane(-construct.world.GAlongGravity():normalize_inplace())
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