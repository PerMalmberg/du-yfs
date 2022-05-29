local construct = require("abstraction/Construct")()
local brakes = require("Brakes")()
local ApproachWaypoint = require("movement/state/ApproachWaypoint")
local MoveTowardsWaypoint = require("movement/state/MoveTowardsWaypoint")
local ctrl = library.GetController()
local Vec3 = require("cpml/ve3")
local nullVec = Vec3()
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

function state:Flush(waypoint, previousWaypoint)
    local brakeDistance, _ = brakes:BrakeDistance()

    if waypoint:DistanceTo() <= brakeDistance then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    elseif construct.velocity.Movement():len() <= waypoint.maxSpeed then
        self.fsm:SetState(MoveTowardsWaypoint(self.fsm))
    else
        self.fsm:Thrust(nullVec)
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