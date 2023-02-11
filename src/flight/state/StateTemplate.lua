---@class FlightState
---@field New fun(fsm:FlightFSM)
---@field Enter fun()
---@field Leave fun()
---@field Flush fun(deltaTime:number, next:Waypoint, previous:Waypoint, nearestPointOnPath:Vec3)
---@field AtWaypoint fun(isLastWaypoint:boolean, next:Waypoint, previous:Waypoint)
---@field InhibitsThrust fun():boolean
---@field MayContinueToNextWaypoint fun():boolean
---@field Update fun()
---@field Name fun():string


local NameOfState = {}
NameOfState.__index = NameOfState
local name = "NameOfState"

---@param fsm FlightFSM
---@return NameOfState
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

    function s.MayContinueToNextWaypoint()
        return false
    end

    function s.Name()
        return name
    end

    ---Inihibits thrust
    function s.InhibitsThrust()
        return false
    end

    return setmetatable(s, NameOfState)
end

return NameOfState
