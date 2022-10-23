local r = require("CommonRequire")
local checks = r.checks

---@module "flight/state/Travel"

---@class Hold
---@field Enter fun()
---@field Leave fun()
---@field Flush fun(deltaTime:number, next:Waypoint, previous:Waypoint, chaseData:ChaseData)
---@field WaypointReached fun(isLastWaypoint:boolean, next:Waypoint, previous:Waypoint)
---@field Update fun()
---@field Name fun():string

local Hold = {}
Hold.__index = Hold

local name = "Hold"

---Creates a new Hold state
---@param fsm FlightFSM
---@return Hold
function Hold.New(fsm)

    local s = {}

    function s.Enter()

    end

    function s.Leave()

    end

    function s.Flush(deltaTime, next, previous, chaseData)
        if next.Reached() then
            next.SetPrecisionMode(true)
        else
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

    setmetatable(s, Hold)

    return s
end

return Hold
