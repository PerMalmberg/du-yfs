local construct = require("abstraction/Construct")()
local brakes = require("Brakes")()
local diag = require("Diagnostics")()

local state = {}
state.__index = state

local name = "Decelerate"

local function new(fsm)
    diag:AssertIsTable(fsm, "fsm", name .. ":new")

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
    local brakeDistance, _ = brakes:BrakeDistance()

    if next:DistanceTo() <= brakeDistance then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    elseif construct.velocity.Movement():len() <= next.maxSpeed then
        self.fsm:SetState(Travel(self.fsm))
    else
        self.fsm:Thrust() -- Just counter gravity, let the brakes do its job
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