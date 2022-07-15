local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
local vehicle = require("du-libs:abstraction/Vehicle")()
local calc = require("du-libs:util/Calc")

local state = {}
state.__index = state
local name = "ReturnToPath"

local function new(fsm)
    checks.IsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm
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
    local toNearest = chaseData.nearest - currentPos
    local distance = toNearest:len()

    if distance <= next.margin then
        self.fsm:Thrust()
        self.fsm:SetState(Travel(self.fsm))
    else
        local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance(toNearest:len())

        local travelDir = vehicle.velocity:Movement():normalize_inplace()
        local dot = travelDir:dot(toNearest:normalize())

        -- Enable brakes if we're moving in the wrong direction, but don't counter all
        -- the movement acceleration so that we actually get anywhere
        local needToBrake = brakeDistance >= next:DistanceTo() or dot < 0.7
        local level = 1

        if dot > 0 then
            level = calc.Scale(dot, 0, 1, 1, 0.95)
        end

        brakes:Set(needToBrake, level)
        self.fsm:Thrust(brakeAccelerationNeeded * -vehicle.velocity.Movement():normalize_inplace())
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