local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
local vehicle = require("du-libs:abstraction/Vehicle")()
local calc = require("du-libs:util/Calc")
local Stopwatch = require("du-libs:system/StopWatch")

local state = {}
state.__index = state
local name = "ReturnToPath"

local function new(fsm)
    checks.IsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm,
        sw = Stopwatch()
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
end

function state:Leave()
end

function state:Flush(next, previous, chaseData)
    local currentPos = vehicle.position.Current()

    -- Remember that chaseData.nearest is the same point that FSM:AdjustForDeviation is working against.
    local toNearest = chaseData.nearest - currentPos
    local distance = toNearest:len()

    if distance <= next.margin then
        if not self.sw:IsRunning() then
            self.sw:Start()
        end

        brakes:Set(true)
        self.fsm:Thrust()

        if self.sw:Elapsed() > 1 then
            self.fsm:SetState(Travel(self.fsm))
        end
    else
        self.sw:Stop()
        local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance(toNearest:len())

        local vel = vehicle.velocity:Movement()
        local travelDir = vel:normalize_inplace()
        local dot = travelDir:dot(toNearest:normalize())

        -- Enable brakes if we're moving in the wrong direction, but don't counter all
        -- the movement acceleration so that we actually get anywhere
        local needToBrake = brakeDistance >= distance or (dot < 0.7 and vel:len() > 0.1)
        local level = 1

        if dot > 0 then
            level = calc.Scale(dot, 0, 1, 1, 0.5)
        end

        brakes:Set(needToBrake, level)
        self.fsm:Thrust()
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