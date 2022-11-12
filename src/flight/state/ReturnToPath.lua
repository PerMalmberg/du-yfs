local Stopwatch = require("system/Stopwatch")
local Waypoint = require("flight/Waypoint")

---@class ReturnToPath
---@field Enter fun()
---@field Leave fun()
---@field Flush fun(deltaTime:number, next:Waypoint, previous:Waypoint, chaseData:ChaseData)
---@field Update fun()
---@field Name fun():string

local ReturnToPath = {}
ReturnToPath.__index = ReturnToPath
local name = "ReturnToPath"

---Creates a new ReturnPath
---@param fsm FlightFSM
---@param returnPoint Vec3
---@return ReturnToPath
function ReturnToPath.New(fsm, returnPoint)
    local s = {}
    local temporaryWP = nil ---@type Waypoint|nil

    function s.Enter()
    end

    function s.Leave()
        fsm.SetTemporaryWaypoint()
    end

    ---Flush
    ---@param deltaTime number
    ---@param next Waypoint
    ---@param previous Waypoint
    ---@param chaseData table
    function s.Flush(deltaTime, next, previous, chaseData)
        if not temporaryWP then
            temporaryWP = Waypoint.New(returnPoint, 0, 0, next.Margin(), next.Roll, next.YawAndPitch)
            fsm.SetTemporaryWaypoint(temporaryWP)
        end

        if temporaryWP.Reached() then
            fsm.SetState(Travel.New(fsm))
        end
    end

    function s.Update()
    end

    function s.WaypointReached(isLastWaypoint, next, previous)
    end

    function s.Name()
        return name
    end

    function s.InhibitsThrust()
        return false
    end

    return setmetatable(s, ReturnToPath)
end

return ReturnToPath
