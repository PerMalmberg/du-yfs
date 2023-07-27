local timer      = require("system/Timer").Instance()
local pub        = require("util/PubSub").Instance()
local vehicle    = require("abstraction/Vehicle").New()
local CurrentPos = vehicle.position.Current
local IsFrozen   = vehicle.player.IsFrozen

---@class Travel
---@field New fun(fsm:FlightFSM):FlightState

local Travel     = {}
Travel.__index   = Travel

local name       = "Travel"

---Creates a new Travel state
---@param fsm FlightFSM
---@return FlightState
function Travel.New(fsm)
    local s = {}

    local function openGate()
        -- When in manual mode, we don't open or close the gate
        if not IsFrozen() then
            pub.Publish("SendData", { topic = "GateControl", data = { desiredDoorState = "open" } })
        end
    end

    function s.Enter()
        -- Immediately open gate, then repeat evey second.
        openGate()
        timer.Add("OpenGate", openGate, 1)
    end

    function s.Leave()
        timer.Remove("OpenGate")
    end

    ---Flush
    ---@param deltaTime number
    ---@param next Waypoint
    ---@param previous Waypoint
    ---@param nearestPointOnPath Vec3
    function s.Flush(deltaTime, next, previous, nearestPointOnPath)
        -- Are we on the the desired path?
        if not fsm.CheckPathAlignment(CurrentPos(), nearestPointOnPath, previous, next) then
            fsm.SetState(ReturnToPath.New(fsm, nearestPointOnPath))
        end
    end

    function s.Update()
    end

    function s.AtWaypoint(isLastWaypoint, next, previous)
        if isLastWaypoint then
            fsm.SetState(Hold.New(fsm))
        end
    end

    function s.Name()
        return name
    end

    function s.InhibitsThrust()
        return false
    end

    return setmetatable(s, Travel)
end

return Travel
