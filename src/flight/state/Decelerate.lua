local construct = require("du-libs:abstraction/Construct")()
local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
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

function state:Flush(next, previous, rabbit)
    local brakeDistance, neededBrakeAcceleration = brakes:BrakeDistance(next:DistanceTo())

    if next:DistanceTo() <= brakeDistance or neededBrakeAcceleration > 0 then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    elseif construct.velocity.Movement():len() <= next.maxSpeed then
        self.fsm:SetState(Travel(self.fsm))
    else
        self.fsm:NullThrust()
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