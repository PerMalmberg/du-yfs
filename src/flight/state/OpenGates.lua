local gateControl = require("controller/GateControl").Instance()
local log         = require("debug/Log").Instance()
local timer       = require("system/Timer").Instance()
local Waypoint    = require("flight/Waypoint")
local Stopwatch   = require("system/Stopwatch")

---@class OpenGates
---@field New fun(fsm:FlightFSM, holdPoint:Vec3, holdDir:Vec3):FlightState

local OpenGates   = {}
OpenGates.__index = OpenGates

local name        = "OpenGates"

---Creates a new OpenGates state
---@param fsm FlightFSM
---@param holdPoint Vec3
---@param holdDir Vec3
---@return FlightState
function OpenGates.New(fsm, holdPoint, holdDir)
    local s = {}
    local temporaryWP = nil ---@type Waypoint|nil
    local commEnabled = fsm.GetSettings().String("commChannel") ~= ""
    local timeToWaitForOpen = fsm.GetSettings().Number("openGateWaitDelay")
    local waitToOpen = Stopwatch.New()

    function s.Enter()
        if commEnabled then
            gateControl.Open()
            log.Info("Requesting gates to open.")
            timer.Add("WaitOnGate", function() log.Info("Waiting on gates to open") end, 2)
        end
    end

    function s.Leave()
        timer.Remove("WaitOnGate")
        fsm.SetTemporaryWaypoint()
    end

    ---Flush
    ---@param deltaTime number
    ---@param next Waypoint
    ---@param previous Waypoint
    ---@param nearestPointOnPath Vec3
    function s.Flush(deltaTime, next, previous, nearestPointOnPath)
        if not temporaryWP then
            temporaryWP = Waypoint.New(holdPoint, 0, 0, next.Margin())
            temporaryWP.LockYawTo(holdDir)
            fsm.SetTemporaryWaypoint(temporaryWP)
        end
    end

    function s.Update()
        if commEnabled then
            if gateControl.AreInDesiredState() then
                if waitToOpen.Elapsed() > timeToWaitForOpen then
                    fsm.SetState(Travel.New(fsm))
                elseif not waitToOpen.IsRunning() then
                    waitToOpen.Start()
                    log.Info("Giving gates ", timeToWaitForOpen, " seconds to be fully open")
                end
            end
        else
            fsm.SetState(Travel.New(fsm))
        end
    end

    function s.AtWaypoint(isLastWaypoint, next, previous)

    end

    function s.Name()
        return name
    end

    function s.DisablesAllThrust()
        return false
    end

    function s.PreventNextWp()
        return true
    end

    return setmetatable(s, OpenGates)
end

return OpenGates
