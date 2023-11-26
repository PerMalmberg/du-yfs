require("abstraction/Vehicle")
local si                = require("Singletons")
local calc, universe    = si.calc, si.universe
local Ternary, max, abs = calc.Ternary, math.max, math.abs

---@enum WPReachMode
WPReachMode             = {
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
---@field IsLastInRoute fun():boolean
---@field IsYawLocked fun():boolean
---@field LockYawTo fun(direction:Vec3|nil, forced:boolean?)
---@field Margin fun():number
---@field MaxSpeed fun():number
---@field Pitch fun(prev:Waypoint):Vec3|nil
---@field Roll fun(prev:Waypoint):Vec3|nil
---@field SetAlignmentAngleLimit fun(limit:number)
---@field SetAlignmentDistanceLimit fun(limit:number)
---@field SetPitchAlignmentThrustLimiter fun(angle:number)
---@field SetLastInRoute fun(lastInRoute:boolean)
---@field WithinMargin fun(mode:WPReachMode):boolean
---@field Yaw fun(prev:Waypoint):Vec3|nil
---@field LockedYawDirection fun():Vec3|nil
---@field ForceUpAlongVerticalRef fun()
---@field PathAlignmentDistanceLimitFromSurface fun():number
---@field PreCalc fun(prev:Waypoint)
---@field SetAutoPitch fun(enabled:boolean)


local Waypoint = {}
Waypoint.__index = Waypoint

-- Return a direction target point this far from the waypoint so that in case we overshoot
-- we don't get the point behind us and start turning around and also reduces oscilliating yaw.
local directionMargin = 1000
Waypoint.DirectionMargin = directionMargin
local pathAlignmentAngleLimit, pathAlignmentDistanceLimit, pitchAlignmentThrustLimiter, autoPitch = 0, 0, 0, false

---@param angle number
function Waypoint.SetAlignmentAngleLimit(angle)
    pathAlignmentAngleLimit = max(0, angle)
end

---@param distance number
function Waypoint.SetAlignmentDistanceLimit(distance)
    pathAlignmentDistanceLimit = max(0, distance)
end

function Waypoint.SetPitchAlignmentThrustLimiter(angle)
    pitchAlignmentThrustLimiter = angle
end

function Waypoint.SetAutoPitch(enable)
    autoPitch = enable
end

---Creates a new Waypoint
---@param destination Vec3 The destination
---@param finalSpeed number The final speed to reach when at the waypoint (0 if stopping is intended).
---@param maxSpeed number The maximum speed to to travel at. Less than or equal to finalSpeed.
---@param margin number The number of meters to be within for the waypoint to be considered reached
---@param pathAlignmentDistanceLimitFromSurface number The minimum distance to the closest body where the construct will align topside along the path
---@return Waypoint
function Waypoint.New(destination, finalSpeed, maxSpeed, margin, pathAlignmentDistanceLimitFromSurface)
    maxSpeed = Ternary(finalSpeed > maxSpeed and maxSpeed > 0, finalSpeed, maxSpeed) -- Guard against bad settings.
    local yawLockDir = nil ---@type Vec3|nil
    local lastInRoute, forceUpAlongVerticalRef, verticalUp, useAutoPitch = false, false, Vec3.zero, autoPitch

    local s = {}

    ---Gets the vertical up reference to use
    ---@param prev Waypoint Previous waypoint
    ---@return Vec3
    local function getVerticalUpReference(prev)
        -- When next waypoint is nearly aligned with -gravity, use the line between them as the vertical reference instead to make following the path more exact.
        local vertUp = -universe.VerticalReferenceVector()

        if forceUpAlongVerticalRef then
            return vertUp
        end

        local selectedRef = vertUp

        local pathDirection = (destination - prev.Destination()):Normalize()
        local body = universe.ClosestBody(Current())
        local distanceToSurface = body.DistanceToHighestPossibleSurface(Current())
        local awayFromWaypoints = s.DistanceTo() > pathAlignmentDistanceLimit and
            prev.DistanceTo() > pathAlignmentDistanceLimit

        if awayFromWaypoints then
            local farOut = pathAlignmentDistanceLimitFromSurface > 0
                and distanceToSurface > pathAlignmentDistanceLimitFromSurface

            if farOut then
                -- We're far out from the nearest body, allow aligning topside along path, even upside down
                selectedRef = pathDirection
                -- Disable auto pitch when tilting along the path
                useAutoPitch = false
            elseif pathAlignmentAngleLimit > 0 then           -- if zero, it means the alignment is disabled
                local sameDir = vertUp:Dot(pathDirection) > 0 -- Same direction?
                if sameDir and vertUp:AngleToDeg(pathDirection) < pathAlignmentAngleLimit then
                    -- If we're more aligned to the path than the threshold, then align to the path
                    selectedRef = pathDirection
                elseif not sameDir and vertUp:AngleToDeg(-pathDirection) < pathAlignmentAngleLimit then
                    -- Don't flip upside down
                    selectedRef = -pathDirection
                end
            end
        end


        return selectedRef
    end

    ---Gets the destination
    ---@return Vec3
    function s.Destination()
        return destination
    end

    ---Gets the final speed for the waypoint
    ---@return number
    function s.FinalSpeed()
        return finalSpeed
    end

    ---Gets the max speed for the waypoint
    ---@return number
    function s.MaxSpeed()
        return maxSpeed
    end

    ---Gets the margin for the waypoint
    ---@return number
    function s.Margin()
        return margin
    end

    ---Indicates if the waypoint has been reached.
    ---@param mode WPReachMode
    ---@return boolean
    function s.WithinMargin(mode)
        local m = margin

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
        return (destination - Current()):Len()
    end

    ---Gets the direction to the waypoint
    ---@return Vec3
    function s.DirectionTo()
        return (destination - Current()):NormalizeInPlace()
    end

    function s.SetLastInRoute(last)
        lastInRoute = last
    end

    function s.IsLastInRoute()
        return lastInRoute
    end

    function s.PathAlignmentDistanceLimitFromSurface()
        return pathAlignmentDistanceLimitFromSurface
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

    ---@param prev Waypoint
    function s.PreCalc(prev)
        verticalUp = getVerticalUpReference(prev)
    end

    function s.ForceUpAlongVerticalRef()
        forceUpAlongVerticalRef = true
    end

    ---@param prev Waypoint
    ---@return Vec3
    local function rollTopsideAwayFromVerticalReference(prev)
        return Current() + verticalUp * directionMargin
    end

    ---@param prev Waypoint
    local function pitchKeepOrtogonalToVerticalRef(prev)
        local forward = verticalUp:Cross(Right())
        local right = forward:Cross(verticalUp)
        return calc.ProjectPointOnPlane(right, Current(), Current() + forward * directionMargin)
    end

    ---@param prev Waypoint
    ---@return Vec3|nil
    function s.Roll(prev)
        return rollTopsideAwayFromVerticalReference(prev)
    end

    ---@param prev Waypoint
    ---@return Vec3|nil
    function s.Pitch(prev)
        if useAutoPitch then
            local moveDir, angleToVert, forward = Velocity():Normalize(), verticalUp:AngleToDeg(s.DirectionTo()),
                verticalUp:Cross(Right())
            if s.DistanceTo() > 10 and Velocity():Len() > calc.Kph2Mps(50)
                and moveDir:AngleToDeg(s.DirectionTo()) <= calc.Clamp(pitchAlignmentThrustLimiter * 10, pitchAlignmentThrustLimiter, 45) --
                and angleToVert > 15 and angleToVert < 180 - 15                                                                          -- Not going vertically
                and forward:Dot(s.DirectionTo()) > 0                                                                                     -- Not reversing
            then
                local right = forward:Cross(verticalUp)
                local target = Current() + moveDir * directionMargin
                return calc.ProjectPointOnPlane(right, Current(), target)
            end
        end

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

        -- To prevent spinning, lock yaw if we're aligning to vertical up
        if not yawLockDir and abs(dir:Dot(verticalUp)) > 0.9 then
            s.LockYawTo(Forward(), false)
            dir = Forward()
        end

        return calc.ProjectPointOnPlane(verticalUp, Current(), Current() + dir * directionMargin)
    end

    return setmetatable(s, Waypoint)
end

return Waypoint
