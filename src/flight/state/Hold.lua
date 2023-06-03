---@module "flight/state/Travel"
---@module "element/Telemeter"
local pub = require("util/PubSub").Instance()
local Stopwatch = require("system/Stopwatch")
local log = require("debug/Log").Instance()


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
    local watch = Stopwatch.New()

    local settings = fsm.GetSettings()

    function s.Enter()
        pub.RegisterTable("FloorMonitor", s.floorMonitor)
        watch.Start()
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
        if player.isFrozen() == 0
            and isLastWaypoint
            and hit.Hit
            and hit.Distance <= settings.Get("autoShutdownFloorDistance") then
            log.Info("Floor detected at last waypoint, shutting down.")
            unit.exit()
        end
    end

    function s.InhibitsThrust()
        return false
    end

    setmetatable(s, Hold)

    return s
end

return Hold
