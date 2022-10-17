local checks = require("CommonRequire").checks

---@class Idle
---@field Enter fun()
---@field Leave fun()
---@field Flush fun(deltaTime:number, next:Waypoint, previous:Waypoint, chaseData:ChaseData)
---@field WaypointReached fun(isLastWaypoint:boolean, next:Waypoint, previous:Waypoint)
---@field Update fun()
---@field Name fun():string

local Idle = {}
Idle.__index = Idle

local name = "Idle"

---Creates a new Idle state
---@param fsm FlightFSM
---@return Idle
function Idle.New(fsm)
    checks.IsTable(fsm, "fsm", name .. ":new")
    local s = {}

    function s.Enter()
    end

    function s.Leave()
    end

    function s.Flush(deltaTime, next, previous, chaseData)
        fsm.DisableThrust()
    end

    function s.Update()
    end

    function s.WaypointReached(isLastWaypoint, next, previous)
    end

    function s.Name()
        return name
    end

    return setmetatable(s, Idle)
end

return Idle
