local construct = require("abstraction/Construct")()
local brakes = require("Brakes")()
local diag = require("Diagnostics")()
local vec3 = require("cpml/vec3")
local Timer = require("Timer")
local calc = require("Calc")
local nullVec = vec3()
local min = math.min

local state = {}
state.__index = state

local name = "Travel"

local function new(fsm)
    diag:AssertIsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm,
        timer = Timer()
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
    brakes:Set(false)
    self.timer:Start()
end

function state:Leave()
end

function state:Flush(next, previous, rabbit)
    local rampTime = 5
    local elapsed = min(self.timer:Elapsed(), rampTime)
    local multi = calc.Scale(elapsed, 0, rampTime, 0, 1)

    local brakeDistance, neededBrakeAcceleration = brakes:BrakeDistance(next:DistanceTo())
    local speed = construct.velocity:Movement():len()
    local currentPos = construct.position.Current()

    local directionToRabbit = (rabbit - currentPos):normalize_inplace()

    if neededBrakeAcceleration > 0 or brakeDistance >= next:DistanceTo() then
        system.print("--> " .. next:DistanceTo() .. " / " .. brakeDistance)
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    elseif speed > next.maxSpeed then
        self.fsm:SetState(Decelerate(self.fsm))
    elseif speed <= next.maxSpeed * 0.99 then
        self.fsm:Thrust(directionToRabbit * next.acceleration * multi)
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