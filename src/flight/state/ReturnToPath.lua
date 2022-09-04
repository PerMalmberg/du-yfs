local r = require("CommonRequire")
local checks = r.checks
local Stopwatch = require("system/Stopwatch")
local Waypoint = require("flight/Waypoint")

local state = {}
state.__index = state
local name = "ReturnToPath"

local function new(fsm, returnPoint)
    checks.IsTable(fsm, "fsm", name .. ":new")
    checks.IsVec3(returnPoint, "returnPoint", name .. ":new")

    local o = {
        fsm = fsm,
        returnPoint = returnPoint,
        returnPointAdjusted = false,
        sw = Stopwatch(),
        temporaryWP = false
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
end

function state:Leave()
    self.fsm:SetTemporaryWaypoint()
end

function state:Flush(deltaTime, next, previous, chaseData)
    if not self.temporaryWP then
        self.temporaryWP = Waypoint(self.returnPoint, 0, 0, next.margin, next.rollFunc, next.yawPitchFunc)
        self.fsm:SetTemporaryWaypoint(self.temporaryWP)
    end

    local timer = self.sw
    if self.temporaryWP:Reached() then
        timer:Start()

        if timer:Elapsed() > 0.3 then
            self.fsm:SetState(Travel(self.fsm))
        end
    else
        timer:Stop()
    end
end

function state:OverrideAdjustPoint()
    return self.returnPoint
end

function state:Update()
end

function state:WaypointReached(isLastWaypoint, next, previous)
end

function state:Name()
    return name
end

return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                return new(...)
            end
        }
)