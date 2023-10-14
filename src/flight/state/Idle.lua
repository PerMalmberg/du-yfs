local pub     = require("util/PubSub").Instance()
local log     = require("debug/Log").Instance()
local vehicle = require("abstraction/Vehicle").New()
local Current = vehicle.position.Current
local Forward = vehicle.orientation.Forward

---@class Idle
---@field New fun(fsm:FlightFSM):FlightState
---@field Enter fun()
---@field Leave fun()
---@field Flush fun(deltaTime:number, next:Waypoint, previous:Waypoint, nearestPointOnPath:Vec3)
---@field AtWaypoint fun(isLastWaypoint:boolean, next:Waypoint, previous:Waypoint)
---@field Update fun()
---@field Name fun():string

local Idle    = {}
Idle.__index  = Idle

local name    = "Idle"

---Creates a new Idle state
---@param fsm FlightFSM
---@return FlightState
function Idle.New(fsm)
    local s = {}

    local settings = fsm.GetSettings()

    function s.Enter()
        pub.RegisterTable("FloorMonitor", s.floorMonitor)
    end

    function s.Leave()
        pub.Unregister("FloorMonitor", s.floorMonitor)
    end

    ---@param deltaTime number
    ---@param next Waypoint
    ---@param previous Waypoint
    ---@param nearestPointOnPath Vec3
    function s.Flush(deltaTime, next, previous, nearestPointOnPath)

    end

    function s.Update()
    end

    function s.AtWaypoint(isLastWaypoint, next, previous)
    end

    function s.Name()
        return name
    end

    function s.DisablesAllThrust()
        return true
    end

    ---@param topic string
    ---@param hit TelemeterResult
    function s.floorMonitor(topic, hit)
        if not hit.Hit or hit.Distance > settings.Get("autoShutdownFloorDistance") then
            log.Info("Floor not detected, holding position.")
            fsm.GetRouteController().ActivateHoldRoute()
            fsm.GetFlightCore().StartFlight()
        end
    end

    function s.PreventNextWp()
        return false
    end

    return setmetatable(s, Idle)
end

return Idle
