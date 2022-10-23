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

    function s.Flush(deltaTime, next, previous, chaseData)
        local currentPos = CurrentPos()

        if not fsm.CheckPathAlignment(currentPos, chaseData) then
            -- Are we on the the desired path?
            fsm.SetState(ReturnToPath.New(fsm, chaseData.nearest))
        end
    end

    function s.Update()
    end

    function s:WaypointReached(isLastWaypoint, next, previous)
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
