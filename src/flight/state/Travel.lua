local constants = require("du-libs:abstraction/Constants")
local construct = require("du-libs:abstraction/Construct")()
local checks = require("du-libs:debug/Checks")
local brakes = require("flight/Brakes")()
local engine = require("du-libs:abstraction/Engine")()
require("flight/state/Require")

local state = {}
state.__index = state

local name = "Travel"

local function new(fsm)
    checks.IsTable(fsm, "fsm", name .. ":new")

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

function state:Flush(next, previous, chaseData)
    local brakeDistance, neededBrakeAcceleration = brakes:BrakeDistance(next:DistanceTo())
    local velocity = construct.velocity:Movement()
    local speed = velocity:len()
    local currentPos = construct.position.Current()

    local directionToRabbit = (chaseData.rabbit - currentPos):normalize_inplace()

    if brakeDistance >= next:DistanceTo() or neededBrakeAcceleration > 0 then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    elseif speed > next.maxSpeed then
        self.fsm:SetState(Decelerate(self.fsm))
    else
        -- Word of warning for my future self. Quickly toggling the brakes causes
        -- them to push the construct off the trajectory.
        local acc = engine:GetMaxAccelerationAlongAxis(directionToRabbit)
        local speedNextFlush = (velocity + acc * constants.PHYSICS_INTERVAL):len()
        
        if speedNextFlush < next.maxSpeed then
            self.fsm:Thrust(directionToRabbit * acc)
        else
            self.fsm:Thrust()
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