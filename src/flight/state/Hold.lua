---@module "flight/state/Travel"
---@module "element/Telemeter"

local pub       = require("util/PubSub").Instance()
local log       = require("debug/Log").Instance()
local timer     = require("system/Timer").Instance()
local Stopwatch = require("system/Stopwatch")
local vehicle   = require("abstraction/Vehicle").New()
local IsFrozen  = vehicle.player.IsFrozen


---@class Hold
---@field New fun(fsm:FlightFSM):FlightState
---@field Enter fun()
---@field Leave fun()
---@field Flush fun(deltaTime:number, next:Waypoint, previous:Waypoint, nearestPointOnPath:Vec3)
---@field AtWaypoint fun(isLastWaypoint:boolean, next:Waypoint, previous:Waypoint)
---@field Update fun()
---@field Name fun():string

local Hold = {}
Hold.__index = Hold

local name = "Hold"

---Creates a new Hold state
---@param fsm FlightFSM
---@return FlightState
function Hold.New(fsm)
    local s = {}
    local isLastWaypoint = false
    local settings = fsm.GetSettings()
    local closeTimeout = Stopwatch.New()

    function s.Enter()
        pub.RegisterTable("FloorMonitor", s.floorMonitor)
        timer.Add("CloseGate", s.closeGates, 0.5)
        closeTimeout.Start()
    end

    function s.Leave()
        pub.Unregister("FloorMonitor", s.floorMonitor)
        timer.Remove("CloseGate")
    end

    ---@param deltaTime number
    ---@param next Waypoint
    ---@param previous Waypoint
    ---@param nearestPointOnPath Vec3
    function s.Flush(deltaTime, next, previous, nearestPointOnPath)
        if not next.WithinMargin(WPReachMode.EXIT) then
            fsm.SetState(Travel.New(fsm))
        end
    end

    function s.Update()
    end

    function s.AtWaypoint(lastWaypoint, next, previous)
        isLastWaypoint = lastWaypoint
    end

    function s.Name()
        return name
    end

    ---@param topic string
    ---@param hit TelemeterResult
    function s.floorMonitor(topic, hit)
        if not IsFrozen()
            and isLastWaypoint
            and hit.Hit
            and hit.Distance <= settings.Get("autoShutdownFloorDistance") then
            log.Info("Floor detected at last waypoint, shutting down.")
            unit.exit()
        end
    end

    function s.closeGates()
        -- When in manual mode, we don't open or close the gate
        if not IsFrozen() and closeTimeout.Elapsed() > settings.Number("gateCloseDelay") then
            pub.Publish("SendData", { topic = "GateControl", data = { desiredDoorState = "closed" } })
        end
    end

    function s.InhibitsThrust()
        return false
    end

    setmetatable(s, Hold)
    return s
end

return Hold
