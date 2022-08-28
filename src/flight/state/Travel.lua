local r = require("CommonRequire")
local vehicle = r.vehicle
local checks = r.checks
local library = r.library
local calc = r.calc
require("flight/state/Require")
local Stopwatch = require("du-libs:system/Stopwatch")
local CurrentPos = vehicle.position.Current

local state = {}
state.__index = state

local name = "Travel"

local function new(fsm)
    checks.IsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm,
        core = library:GetCoreUnit(),
        rampTimer = Stopwatch()
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
    self.rampTimer:Start()
end

function state:Leave()
end

function state:Flush(next, previous, chaseData)
    local currentPos = CurrentPos()

    local directionToRabbit = (chaseData.rabbit - currentPos):normalize_inplace()

    if not self.fsm:CheckPathAlignment(currentPos, chaseData) then
        -- Are we on the the desired path?
        self.fsm:SetState(ReturnToPath(self.fsm, chaseData.nearest))
    else
        -- Ramp up the acceleration based on engine warmup to prevent pushing ourselves off the path.
        local mul = calc.Scale(self.rampTimer:Elapsed(), 0, self.fsm:GetEngineWarmupTime(), 0, 1)
        self.fsm:Move(directionToRabbit, next:DistanceTo(), next.maxSpeed, mul)
    end
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