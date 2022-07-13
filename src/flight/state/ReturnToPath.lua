local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
local vehicle = require("du-libs:abstraction/Vehicle")()

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

    self.fsm:Thrust()

    if distance <= next.margin then
        self.fsm:SetState(Travel(self.fsm))
    else
        local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance(toNearest:len())

        local travelDir = vehicle.velocity:Movement():normalize_inplace()
        local enableBrake = travelDir:dot(toNearest:normalize()) < 0.7

        brakes:Set(enableBrake)
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