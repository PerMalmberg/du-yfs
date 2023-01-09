local r = require("CommonRequire")
local vehicle = r.vehicle
local CurrentPos = vehicle.position.Current

---@class Travel

local Travel = {}
Travel.__index = Travel

local name = "Travel"

---Creates a new Travel state
---@param fsm FlightFSM
---@return Travel
function Travel.New(fsm)
    local s = {}

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
        if not fsm.CheckPathAlignment(CurrentPos(), nearestPointOnPath, previous, next) then
            fsm.SetState(ReturnToPath.New(fsm, nearestPointOnPath))
        end
    end

    function s.Update()
    end

    function s.WaypointReached(isLastWaypoint, next, previous)
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
