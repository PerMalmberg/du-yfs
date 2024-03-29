---@class FlightState
---@field New fun(fsm:FlightFSM):FlightState
---@field Enter fun()
---@field Leave fun()
---@field Flush fun(deltaTime:number, next:Waypoint, previous:Waypoint, nearestPointOnPath:Vec3)
---@field AtWaypoint fun(isLastWaypoint:boolean, next:Waypoint, previous:Waypoint)
---@field DisablesAllThrust fun():boolean
---@field PreventNextWp fun():boolean
---@field Update fun()
---@field Name fun():string


local NameOfState = {}
NameOfState.__index = NameOfState
local name = "NameOfState"

---@param fsm FlightFSM
---@return FlightState
function NameOfState.New(fsm)
    local s = {}

    function s.Enter()
    end

    function s.Leave()
    end

    ---@param deltaTime number
    ---@param next Waypoint
    ---@param previous Waypoint
    ---@param nearestPointOnPath Vec3
    function s.Flush(deltaTime, next, previous, nearestPointOnPath)
    end

    function s.Update()
    end

    function s.AtWaypoint(isLastWaypoint, next, previous)
    end

    function s.Name()
        return name
    end

    ---Controls enablement of of thrust and torque
    ---@return boolean
    function s.DisablesAllThrust()
        return false
    end

    ---If returning true, the construct won't move to the next WP
    ---@return boolean
    function s.PreventNextWp()
        return false
    end

    return setmetatable(s, NameOfState)
end

return NameOfState
