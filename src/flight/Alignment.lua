local max = math.max
local abs = math.abs
local Waypoint = require("flight/Waypoint")
local universe = require("universe/Universe").Instance()
local calc = require("util/Calc")
local vehicle = require("abstraction/Vehicle").New()
local Current = vehicle.position.Current
local Plane = require("math/Plane")

---@class Alignment
---@field Roll fun():Vec3|nil
---@field Yaw fun():Vec3|nil
---@field Pitch fun():Vec3|nil
---@field SetNoseMode fun(pointToNext:boolean)
---@field SetLastInRoute fun(lastInRoute:boolean)
---@field IsLastInRoute fun():boolean
---@field SetWaypoints fun(next:Waypoint, prev:Waypoint)
---@field LockYawTo fun(direction:Vec3|nil, forced:boolean?)
---@field IsYawLocked fun():boolean
---@field DirectionMargin boolean
---@field SetAlignmentAngleLimit fun(limit:number)
---@field SetAlignmentDistanceLimit fun(limit:number)
---@field Instance fun():Alignment

---@alias AlignmentFunction fun(currentWaypoint:Waypoint, previous:Waypoint):{yaw:Vec3, pitch:Vec3}

--[[
This class handles roll/pitch/yaw functionality and the different modes thereof.
It must be fed waypoints via the SetWaypoints function before any subsequent function calls.

]]
--

local Alignment = {}
Alignment.__index = Alignment
local instance ---@type Alignment

-- Return a direction target point this far from the waypoint so that in case we overshoot
-- we don't get the point behind us and start turning around and also reduces oscilliating yaw.
local directionMargin = 1000
Alignment.DirectionMargin = directionMargin

---@return Alignment
function Alignment.Instance()
    if instance then
        return instance
    end

    local s = {}
    local plane = Plane.NewByVertialReference()
    local next = Waypoint.New(Current(), 0, 0, 0.1)
    local prev = Waypoint.New(Current(), 0, 0, 0.1)
    local lastInRoute = false
    local noseMode = false
    local yawLockDir = nil ---@type Vec3|nil
    local pathAlignmentAngleLimit = 40
    local pathAlignmentDistanceLimit = 50

    ---@param angle number
    function s.SetAlignmentAngleLimit(angle)
        pathAlignmentAngleLimit = max(0, angle)
    end

    ---@param distance number
    function s.SetAlignmentDistanceLimit(distance)
        pathAlignmentDistanceLimit = max(0, distance)
    end

    ---Updates the waypoints to work with
    ---@param nextWp Waypoint
    ---@param prevWp Waypoint
    function s.SetWaypoints(nextWp, prevWp)
        next = nextWp
        prev = prevWp

        -- When the next waypoint is nearly above or below us, lock yaw.
        local dir = (next.Destination() - prev.Destination()):NormalizeInPlace()
        if abs(dir:Dot(plane.Up())) > 0.9 then -- <= calc.AngleToDot(25) then
            s.LockYawTo(plane.Forward(), true)
        else
            -- Don't unlock strafing etc.
            s.LockYawTo(nil, false)
        end
    end

    function s.SetLastInRoute(last)
        lastInRoute = last
    end

    function s.IsLastInRoute()
        return lastInRoute
    end

    function s.SetNoseMode(mode)
        noseMode = mode
    end

    ---Locks the yaw direction to the given direction
    ---@param direction Vec3|nil
    ---@param forced boolean? If true, existing locks are overridden
    function s.LockYawTo(direction, forced)
        forced = forced or false
        if yawLockDir == nil or forced then
            yawLockDir = direction
            system.print("Locked")
        end
    end

    function s.IsYawLocked()
        return yawLockDir ~= nil
    end

    function s.GetVerticalUpReference()
        -- When next waypoint is nearly aligned with -gravity, use the line between them as the vertical reference instead to make following the path more exact.
        local vertUp = -universe.VerticalReferenceVector()

        local selectedRef = vertUp

        if pathAlignmentAngleLimit > 0 -- if zero, it means the alignment is disabled
            and next.DistanceTo() > pathAlignmentDistanceLimit and prev.DistanceTo() > pathAlignmentDistanceLimit then
            local threshold = calc.AngleToDot(pathAlignmentAngleLimit)

            local pathDirection = (next.Destination() - prev.Destination()):Normalize()
            -- If we're more aligned to the path than the threshold, then align to the path
            if vertUp:Dot(pathDirection) > threshold then
                selectedRef = pathDirection
            elseif vertUp:Dot(pathDirection) < -threshold then -- Don't flip upside down
                selectedRef = -pathDirection
            end
        end

        return selectedRef
    end

    local function rollTopsideAwayFromVerticalReference()
        return Current() + s.GetVerticalUpReference() * directionMargin
    end

    local function pitchKeepOrtogonalToVerticalRef()
        return Current() + plane.Forward() * directionMargin
    end

    ---@return Vec3|nil
    function s.Roll()
        return rollTopsideAwayFromVerticalReference()
    end

    ---@return Vec3|nil
    function s.Pitch()
        if noseMode and not s.IsLastInRoute() then
            local travelDir = (next.Destination() - prev.Destination()):NormalizeInPlace()
            return Current() + travelDir * directionMargin
        end

        return pitchKeepOrtogonalToVerticalRef()
    end

    ---@return Vec3|nil
    function s.Yaw()
        local dir

        if yawLockDir then
            dir = yawLockDir
        else
            dir = (next.Destination() - prev.Destination()):NormalizeInPlace()
        end

        return Current() + dir * directionMargin
    end

    instance = setmetatable(s, Alignment)
    return instance
end

return Alignment


--[[

function alignment.NoAdjust()
    return nil
end
]]
