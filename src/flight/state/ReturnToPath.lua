require("GlobalTypes")

---@class ReturnToPath
---@field New fun(fsm:FlightFSM, returnPoint:Vec3):FlightState
---@field Enter fun()
---@field Leave fun()
---@field Flush fun(deltaTime:number, next:Waypoint, previous:Waypoint, nearestPointOnPath:Vec3)
---@field Update fun()
---@field Name fun():string

local ReturnToPath = {}
ReturnToPath.__index = ReturnToPath
local name = "ReturnToPath"

---Creates a new ReturnPath
---@param fsm FlightFSM
---@param returnPoint Vec3
---@return FlightState
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
    ---@param nearestPointOnPath Vec3
    function s.Flush(deltaTime, next, previous, nearestPointOnPath)
        if not temporaryWP then
            temporaryWP = Waypoint.New(returnPoint, 0, 0, fsm.GetSettings().Number("minimumPathCheckOffset", 2), 0)
            temporaryWP.LockYawTo(next.LockedYawDirection() or Plane.NewByVertialReference().Forward())
            temporaryWP.ForceUpAlongVerticalRef()
            fsm.SetTemporaryWaypoint(temporaryWP)
        end

        if temporaryWP.WithinMargin(WPReachMode.ENTRY) then
            fsm.SetState(Travel.New(fsm))
        end
    end

    function s.Update()
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
        return false
    end

    return setmetatable(s, ReturnToPath)
end

return ReturnToPath
