local constants = require("du-libs:abstraction/Constants")
local construct = require("du-libs:abstraction/Construct")()
local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
local engine = require("du-libs:abstraction/Engine")()
require("flight/state/Require")

local state = {}
state.__index = state

local name = "Decelerate"

local function new(fsm)
    checks.IsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
    brakes:Set(true)
end

function state:Leave()
    brakes:Set(false)
end

function state:Flush(next, previous, chaseData)
    local brakeDistance, neededBrakeAcceleration = brakes:BrakeDistance(next:DistanceTo())

    if next:DistanceTo() <= brakeDistance or neededBrakeAcceleration > 0 then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    else
        local velocity = construct.velocity:Movement()
        local speedNextFlush = (velocity + construct.acceleration:Movement() * constants.PHYSICS_INTERVAL):len()
        if speedNextFlush <= next.maxSpeed then
            self.fsm:SetState(Travel(self.fsm))
        else
            local dir = construct.velocity.Movement():normalize_inplace()
            self.fsm:Thrust(-dir * engine:GetMaxAccelerationAlongAxis(-dir))
        end
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