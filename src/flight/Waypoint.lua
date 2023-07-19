local vehicle = require("abstraction/Vehicle").New()
local calc = require("util/Calc")
local Ternary = calc.Ternary
local Current = vehicle.position.Current

---@enum WPReachMode
WPReachMode = {
    ENTRY = 1,
    EXIT = 2
}

---@class Waypoint
---@field New fun(destination:Vec3, finalSpeed:number, maxSpeed:number, margin:number):Waypoint
---@field FinalSpeed fun():number
---@field MaxSpeed fun():number
---@field Margin fun():number
---@field WithinMargin fun(mode:WPReachMode):boolean
---@field Destination fun():Vec3
---@field DistanceTo fun():number
---@field DirectionTo fun():Vec3
---@field Roll fun(previous:Waypoint):Vec3
---@field YawAndPitch fun(previous:Waypoint):{yaw:Vec3, pitch:Vec3}|nil

local Waypoint = {}
Waypoint.__index = Waypoint

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

    return setmetatable(s, Waypoint)
end

return Waypoint
