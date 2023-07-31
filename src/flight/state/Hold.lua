---@module "flight/state/Travel"
---@module "element/Telemeter"

local pub         = require("util/PubSub").Instance()
local log         = require("debug/Log").Instance()
local vehicle     = require("abstraction/Vehicle").New()
local IsFrozen    = vehicle.player.IsFrozen
local gateControl = require("controller/GateControl").Instance()
local timer       = require("system/Timer").Instance()


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

    local function waitForGatesToClose()
        timer.Add("WaitForGatesToClose", function()
                unit.exit()
            end,
            settings.Number("gateCloseDelay"))
    end

    function s.Enter()
        pub.RegisterTable("FloorMonitor", s.floorMonitor)
        gateControl.Close()
    end

    function s.Leave()
        pub.Unregister("FloorMonitor", s.floorMonitor)
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
            log.Info("Floor detected at last waypoint, going idle.")
            fsm.SetState(Idle.New(fsm))
            waitForGatesToClose()
        end
    end

    function s.Inhibitions()
        return { thrust = false, alignment = false }
    end

    setmetatable(s, Hold)
    return s
end

return Hold
