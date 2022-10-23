---@class FlightState
---@field Enter fun()
---@field Leave fun()
---@field Flush fun(deltaTime:number, next:Waypoint, previous:Waypoint, chaseData:ChaseData)
---@field WaypointReached fun(isLastWaypoint:boolean, next:Waypoint, previous:Waypoint)
---@field InhibitsThrust fun():boolean
---@field Update fun()
---@field Name fun():string


local State = {}
State.__index = State
local name = "NameOfState"

local function new(fsm)

    local s = {}

    function s.Enter()
    end

    function s.Leave()
    end

    function s.Flush(deltaTime, next, previous, chaseData)
    end

    function s.Update()
    end

    function s.WaypointReached(isLastWaypoint, next, previous)
    end

    function s.Name()
        return name
    end

    ---Inihibits thrust
    function s.InhibitsThrust()
        return false
    end

    setmetatable(o, State)

    return o
end

return State
