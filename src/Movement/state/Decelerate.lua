local construct = require("abstraction/Construct")()
local brakes = require("Brakes")()
local diag = require("Diagnostics")()

local state = {}
state.__index = state

local function new(fsm)
    diag:AssertIsTable(fsm, "fsm", "Decelerate:new")

    local o = {
        fsm = fsm
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
    breaks:Set(true)
end

function state:Leave()
    breaks:Set(false)
end

function state:Flush(next, previous)
    local brakeDistance, _ = brakes:BrakeDistance()

    if next:DistanceTo() <= brakeDistance then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    elseif construct.velocity.Movement():len() <= next.maxSpeed then
        self.fsm:SetState(MoveTowardsWaypoint(self.fsm))
    else
        self.fsm:Thrust()
    end
end

function state:Update()
end

function state:Name()
    return "AccelerateTowardsWaypoint"
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