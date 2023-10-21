require("abstraction/Vehicle")
local s        = require("Singletons")
local floor    = s.floorDetector
local log      = s.log
local uni      = s.universe

---@class Travel
---@field New fun(fsm:FlightFSM):FlightState

local Travel   = {}
Travel.__index = Travel

local name     = "Travel"

---Creates a new Travel state
---@param fsm FlightFSM
---@return FlightState
function Travel.New(fsm)
    local s = {}
    local rc = fsm.GetRouteController()

    function s.Enter()
    end

    function s.Leave()
    end

    ---Flush
    ---@param deltaTime number
    ---@param next Waypoint
    ---@param previous Waypoint
    ---@param nearestPointOnPath Vec3
    function s.Flush(deltaTime, next, previous, nearestPointOnPath)
        -- Are we on the the desired path?
        if not fsm.CheckPathAlignment(Current(), nearestPointOnPath, previous, next) then
            fsm.SetState(ReturnToPath.New(fsm, nearestPointOnPath))
        end
    end

    function s.Update()
        if floor.IsParkingEnabled() then
            local m = floor.Measure()
            if m.Hit then
                fsm.GetFlightCore().StartParking(m.Distance, "Settling")
                floor.EnableParking(false)
            end
        end
    end

    function s.AtWaypoint(isLastWaypoint, next, previous)
        if isLastWaypoint then
            fsm.SetState(Hold.New(fsm))
        end
    end

    function s.Name()
        return name
    end

    function s.DisablesAllThrust()
        return false
    end

    function s.PreventNextWp()
        return false
    end

    return setmetatable(s, Travel)
end

return Travel
