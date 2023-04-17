local alignment = require("flight/AlignmentFunctions")
local r = require("CommonRequire")
local Ternary = r.calc.Ternary
local Current = r.vehicle.position.Current

---@enum WPReachMode
WPReachMode = {
    ENTRY = 1,
    EXIT = 2
}

---@class Waypoint
---@field New fun():Waypoint
---@field FinalSpeed fun():number
---@field MaxSpeed fun():number
---@field Margin fun():number
---@field WithinMargin fun(mode:WPReachMode):boolean
---@field Destination fun():Vec3
---@field DistanceTo fun():number
---@field DirectionTo fun():Vec3
---@field LockDirection fun(direction:Vec3, forced:boolean)
---@field DirectionLocked fun():boolean
---@field Roll fun(previous:Waypoint):Vec3
---@field YawAndPitch fun(previous:Waypoint):{yaw:Vec3, pitch:Vec3}|nil
---@field YawPitchDirection fun():Vec3

local Waypoint = {}
Waypoint.__index = Waypoint

---Creates a new Waypoint
---@param destination Vec3 The destination
---@param finalSpeed number The final speed to reach when at the waypoint (0 if stopping is intended).
---@param maxSpeed number The maximum speed to to travel at. Less than or equal to finalSpeed.
---@param margin number The number of meters to be within for the waypoint to be considered reached
---@param rollFunc AlignmentFunction Function that determines how the constrol aligns its topside (rolls)
---@param yawPitchFunc AlignmentFunction
---@return Waypoint
function Waypoint.New(destination, finalSpeed, maxSpeed, margin, rollFunc, yawPitchFunc)
    local s = {
        destination = destination,
        finalSpeed = finalSpeed,
        maxSpeed = Ternary(finalSpeed > maxSpeed and maxSpeed > 0, finalSpeed, maxSpeed), ---@type number -- Guard against bad settings.
        margin = margin,
        rollFunc = rollFunc,
        yawPitchFunc = yawPitchFunc,
        yawPitchDirection = nil, ---@type Vec3 -- Fixed target direction
        adjusted = false
    }

    ---Gets the destination
    ---@return Vec3
    function s.Destination()
        return s.destination
    end

    ---Gets the yaw/pitch direction
    ---@return Vec3
    function s.YawPitchDirection()
        return s.yawPitchDirection
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

    ---Locks the direction
    ---@param direction Vec3 The direction to lock towards
    ---@param forced boolean If true, overrides existing lock
    function s.LockDirection(direction, forced)
        if s.yawPitchDirection == nil or forced then
            s.yawPitchDirection = direction
            s.yawPitchFunc = alignment.YawPitchKeepLockedWaypointDirectionOrthogonalToVerticalReference
        end
    end

    ---Indicates of the direction is locked
    ---@return boolean
    function s.DirectionLocked()
        return s.yawPitchDirection ~= nil
    end

    ---Performs the roll applicable for this waypoint
    ---@param previousWaypoint Waypoint
    ---@return Vec3|nil
    function s.Roll(previousWaypoint)
        if s.rollFunc ~= nil then
            return s.rollFunc(s, previousWaypoint)
        end

        return nil
    end

    ---Performs the way and pitch applicable for this waypoint
    ---@param previousWaypoint Waypoint
    ---@return {yaw:Vec3, pitch:Vec3}|nil
    function s.YawAndPitch(previousWaypoint)
        if s.yawPitchFunc ~= nil then
            return s.yawPitchFunc(s, previousWaypoint)
        end

        return nil
    end

    return setmetatable(s, Waypoint)
end

return Waypoint
