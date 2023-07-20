local calc = require("util/Calc")
local vehicle = require("abstraction/Vehicle").New()
local constructRight = vehicle.orientation.Right
local universe = require("universe/Universe").Instance()
local Ternary = calc.Ternary
local Current = vehicle.position.Current
local max = math.max

---@enum WPReachMode
WPReachMode = {
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
---@return Waypoint
function Waypoint.New(destination, finalSpeed, maxSpeed, margin)
    local s = {
        destination = destination,
        finalSpeed = finalSpeed,
        maxSpeed = Ternary(finalSpeed > maxSpeed and maxSpeed > 0, finalSpeed, maxSpeed), ---@type number -- Guard against bad settings.
        margin = margin,
        lastPointInRoute = false
    }

    local lastInRoute = false
    local yawLockDir = nil ---@type Vec3|nil

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

    ---Gets the vertical up reference to use
    ---@param prev Waypoint Previous waypoint
    ---@return Vec3
    function s.GetVerticalUpReference(prev)
        -- When next waypoint is nearly aligned with -gravity, use the line between them as the vertical reference instead to make following the path more exact.
        local vertUp = -universe.VerticalReferenceVector()

        local selectedRef = vertUp

        if pathAlignmentAngleLimit > 0 -- if zero, it means the alignment is disabled
            and s.DistanceTo() > pathAlignmentDistanceLimit and prev.DistanceTo() > pathAlignmentDistanceLimit then
            local threshold = calc.AngleToDot(pathAlignmentAngleLimit)

            local pathDirection = (s.Destination() - prev.Destination()):Normalize()
            -- If we're more aligned to the path than the threshold, then align to the path
            if vertUp:Dot(pathDirection) > threshold then
                selectedRef = pathDirection
            elseif vertUp:Dot(pathDirection) < -threshold then -- Don't flip upside down
                selectedRef = -pathDirection
            end
        end

        return selectedRef
    end

    ---@param prev Waypoint
    ---@return Vec3
    local function rollTopsideAwayFromVerticalReference(prev)
        return Current() + s.GetVerticalUpReference(prev) * directionMargin
    end

    ---@param prev Waypoint
    local function pitchKeepOrtogonalToVerticalRef(prev)
        local forward = s.GetVerticalUpReference(prev):Cross(constructRight())

        return Current() + forward * directionMargin
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
        else
            dir = s.DirectionTo()
        end

        return Current() + dir * directionMargin
    end

    return setmetatable(s, Waypoint)
end

return Waypoint
