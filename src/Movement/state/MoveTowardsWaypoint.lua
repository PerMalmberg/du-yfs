local construct = require("abstraction/Construct")()
local brakes = require("Brakes")()
local diag = require("Diagnostics")()
local vec3 = require("cpml/vec3")
local nullVec = vec3()

local state = {}
state.__index = state

local name = "MoveTowardsWaypoint"

local function new(fsm)
    diag:AssertIsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
    brakes:Set(false)
end

function state:Leave()
end

function state:Flush(next, previous)
    local brakeDistance, _ = brakes:BrakeDistance()
    local speed = construct.velocity:Movement():len()
    local currentPos = construct.position.Current()
    local rabbit = self.fsm:NearestPointBetweenWaypoints(previous, next, currentPos, 3)
    local directionToRabbit = (rabbit - currentPos):normalize_inplace()

    if next:DistanceTo() <= brakeDistance then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    elseif speed > next.maxSpeed then
        self.fsm:SetState(Decelerate(self.fsm))
    elseif speed <= next.maxSpeed * 0.99 then
        self.fsm:Thrust(directionToRabbit * next.acceleration)
    else
        self.fsm:Thrust()
    end
end

function state:Update()
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