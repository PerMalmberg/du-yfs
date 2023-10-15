require("abstraction/Vehicle")
local s        = require("Singletons")
local calc     = s.calc
local universe = s.universe
local Ternary  = calc.Ternary
local max      = math.max
local abs      = math.abs

---@enum WPReachMode
WPReachMode    = {
    ENTRY = 1,
    EXIT = 2
}

---@class Waypoint
---@field New fun(destination:Vec3, finalSpeed:number, maxSpeed:number, margin:number):Waypoint
---@field Destination fun():Vec3
---@field DirectionMargin number
---@field DirectionTo fun():Vec3
---@field DistanceTo fun():number
---@field FinalSpeed fun():number
---@field GetVerticalUpReference fun(prev:Waypoint):Vec3
---@field IsLastInRoute fun():boolean
---@field IsYawLocked fun():boolean
---@field LockYawTo fun(direction:Vec3|nil, forced:boolean?)
---@field Margin fun():number
---@field MaxSpeed fun():number
---@field Pitch fun(prev:Waypoint):Vec3|nil
---@field Roll fun(prev:Waypoint):Vec3|nil
---@field SetAlignmentAngleLimit fun(limit:number)
---@field SetAlignmentDistanceLimit fun(limit:number)
---@field SetLastInRoute fun(lastInRoute:boolean)
---@field WithinMargin fun(mode:WPReachMode):boolean
---@field Yaw fun(prev:Waypoint):Vec3|nil
---@field LockedYawDirection fun():Vec3|nil
---@field ForceUpAlongVerticalRef fun()


local Waypoint = {}
Waypoint.__index = Waypoint

-- Return a direction target point this far from the waypoint so that in case we overshoot
-- we don't get the point behind us and start turning around and also reduces oscilliating yaw.
local directionMargin = 1000
Waypoint.DirectionMargin = directionMargin
local pathAlignmentAngleLimit = 0
local pathAlignmentDistanceLimit = 0

---@param angle number
function Waypoint.SetAlignmentAngleLimit(angle)
    pathAlignmentAngleLimit = max(0, angle)
end

---@param distance number
function Waypoint.SetAlignmentDistanceLimit(distance)
    pathAlignmentDistanceLimit = max(0, distance)
end

---Creates a new Waypoint
---@param destination Vec3 The destination
---@param finalSpeed number The final speed to reach when at the waypoint (0 if stopping is intended).
---@param maxSpeed number The maximum speed to to travel at. Less than or equal to finalSpeed.
---@param margin number The number of meters to be within for the waypoint to be considered reached
---@param pathAlignmentDistanceLimitFromSurface number The minimum distance to the closest body where the construct will align topside along the path
---@return Waypoint
function Waypoint.New(destination, finalSpeed, maxSpeed, margin, pathAlignmentDistanceLimitFromSurface)
    local s = {
        destination = destination,
        finalSpeed = finalSpeed,
        maxSpeed = Ternary(finalSpeed > maxSpeed and maxSpeed > 0, finalSpeed, maxSpeed), ---@type number -- Guard against bad settings.
        margin = margin,
        lastPointInRoute = false,
    }

    local lastInRoute = false
    local yawLockDir = nil ---@type Vec3|nil
    local forceUpAlongVerticalRef = false

    ---Gets the destination
    ---@return Vec3
    function s.Destination()
        return s.destination
    end

    ---Gets the final speed for the waypoint
    ---@return number
    function s.FinalSpeed()
        return s.finalSpeed
    end

    ---Gets the max speed for the waypoint
    ---@return number
    function s.MaxSpeed()
        return s.maxSpeed
    end

    ---Gets the margin for the waypoint
    ---@return number
    function s.Margin()
        return s.margin
    end

    ---Indicates if the waypoint has been reached.
    ---@param mode WPReachMode
    ---@return boolean
    function s.WithinMargin(mode)
        local m = s.margin

        if mode == WPReachMode.ENTRY then
            if m > 1 then
                m = m / 2
            end
        end

        return s.DistanceTo() <= m
    end

    ---Gets the distance to the waypoint
    ---@return number
    function s.DistanceTo()
        return (s.destination - Current()):Len()
    end

    ---Gets the direction to the waypoint
    ---@return Vec3
    function s.DirectionTo()
        return (s.destination - Current()):NormalizeInPlace()
    end

    function s.SetLastInRoute(last)
        lastInRoute = last
    end

    function s.IsLastInRoute()
        return lastInRoute
    end

    ---Locks the yaw direction to the given direction
    ---@param direction Vec3|nil
    ---@param forced boolean? If true, existing locks are overridden
    function s.LockYawTo(direction, forced)
        forced = forced or false
        if yawLockDir == nil or forced then
            yawLockDir = direction
        end
    end

    function s.IsYawLocked()
        return yawLockDir ~= nil
    end

    function s.LockedYawDirection()
        return yawLockDir
    end

    ---Gets the vertical up reference to use
    ---@param prev Waypoint Previous waypoint
    ---@return Vec3
    function s.GetVerticalUpReference(prev)
        -- When next waypoint is nearly aligned with -gravity, use the line between them as the vertical reference instead to make following the path more exact.
        local vertUp = -universe.VerticalReferenceVector()

        local selectedRef = vertUp

        if not forceUpAlongVerticalRef then
            local dest = s.Destination()
            local pathDirection = (dest - prev.Destination()):Normalize()
            local body = universe.ClosestBody(Current())
            local distanceToSurface = body.DistanceToHighestPossibleSurface(Current())
            local awayFromWaypoints = s.DistanceTo() > pathAlignmentDistanceLimit and
                prev.DistanceTo() > pathAlignmentDistanceLimit

            if awayFromWaypoints then
                if pathAlignmentDistanceLimitFromSurface > 0
                    and distanceToSurface > pathAlignmentDistanceLimitFromSurface
                then
                    -- We're far out from the nearest body, allow aligning topside along path, even upside down
                    selectedRef = pathDirection
                elseif pathAlignmentAngleLimit > 0 then -- if zero, it means the alignment is disabled
                    local threshold = calc.AngleToDot(pathAlignmentAngleLimit)

                    local vertDotPath = vertUp:Dot(pathDirection)
                    if vertDotPath > threshold then      -- If we're more aligned to the path than the threshold, then align to the path
                        selectedRef = pathDirection
                    elseif vertDotPath < -threshold then -- Don't flip upside down
                        selectedRef = -pathDirection
                    end
                end
            end
        end

        return selectedRef
    end

    function s.ForceUpAlongVerticalRef()
        forceUpAlongVerticalRef = true
    end

    ---@param prev Waypoint
    ---@return Vec3
    local function rollTopsideAwayFromVerticalReference(prev)
        return Current() + s.GetVerticalUpReference(prev) * directionMargin
    end

    ---@param prev Waypoint
    local function pitchKeepOrtogonalToVerticalRef(prev)
        local target = Current() + Forward() * directionMargin
        return calc.ProjectPointOnPlane(s.GetVerticalUpReference(prev), Current(), target)
    end

    ---@param prev Waypoint
    ---@return Vec3|nil
    function s.Roll(prev)
        return rollTopsideAwayFromVerticalReference(prev)
    end

    ---@param prev Waypoint
    ---@return Vec3|nil
    function s.Pitch(prev)
        return pitchKeepOrtogonalToVerticalRef(prev)
    end

    ---@param prev Waypoint
    ---@return Vec3|nil
    function s.Yaw(prev)
        local dir

        if yawLockDir then
            dir = yawLockDir
        elseif s.DistanceTo() > 50 then
            -- Point towards the next point. Use the previous point as a reference when we get close to prevent spinning.
            dir = s.DirectionTo()
        else
            dir = s.Destination() - prev.Destination()
            dir:NormalizeInPlace()
        end

        local vertUp = s.GetVerticalUpReference(prev)

        -- To prevent spinning, lock yaw if we're aligning to vertical up
        if not yawLockDir and abs(dir:Dot(vertUp)) > 0.9 then
            s.LockYawTo(Forward(), false)
            dir = Forward()
        end

        return Current() + dir:ProjectOnPlane(vertUp) * directionMargin
    end

    return setmetatable(s, Waypoint)
end

return Waypoint
