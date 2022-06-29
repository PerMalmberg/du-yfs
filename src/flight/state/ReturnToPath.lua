local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
local vehicle = require("du-libs:abstraction/Vehicle")()
local calc = require("du-libs:util/Calc")
local utils = require("cpml/Utils")

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
    local toTarget = chaseData.nearest - currentPos

    if toTarget:len() <= next.margin then
        self.fsm:SetState(Travel(self.fsm))
    else
        local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance(toTarget:len())

        local travelDir = vehicle.velocity:Movement():normalize_inplace()

        brakes:Set(brakeDistance >= toTarget:len())

        local acc = brakeAccelerationNeeded * -travelDir

        local mul = calc.Scale(utils.clamp(toTarget:len(), 0, 5), 0, 5, 0.5, 2)
        acc = toTarget:normalize() * mul

        self.fsm:Thrust(acc)
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