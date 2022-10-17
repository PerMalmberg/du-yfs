local r = require("CommonRequire")
local checks = r.checks
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

function ReturnToPath.New(fsm, returnPoint)
    checks.IsTable(fsm, "fsm", name .. ":new")
    checks.IsVec3(returnPoint, "returnPoint", name .. ":new")

    local s = {}
    local sw = Stopwatch.New()
    local temporaryWP = nil ---@type Waypoint

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
            sw.Start()

            if sw.Elapsed() > 0.3 then
                fsm.SetState(Travel.New(fsm))
            end
        else
            sw.Stop()
        end
    end

    function s.Update()
    end

    function s.WaypointReached(isLastWaypoint, next, previous)
    end

    function s.Name()
        return name
    end

    return setmetatable(s, ReturnToPath)
end

return ReturnToPath
