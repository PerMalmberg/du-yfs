local vehicle = require("du-libs:abstraction/Vehicle")()
local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
local nullVec = require("cpml/vec3")()
local calc = require("du-libs:util/Calc")
require("flight/state/Require")

local name = "ApproachWaypoint"

local state = {}
state.__index = state

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
    local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance(next:DistanceTo())
    local currentPos = vehicle.position.Current()

    local dist = next:DistanceTo()
    -- Don't switch if we're nearly there
    if brakeDistance < dist and dist > 1000 then
        self.fsm:SetState(Travel(self.fsm))
    elseif not self.fsm:CheckPathAlignment(currentPos, chaseData) then
        -- Are we on the the desired path?
        self.fsm:Thrust()
        self.fsm:SetState(CorrectDeviation(self.fsm))
    else
        local dot = next:DirectionTo():dot(vehicle.velocity.Movement():normalize_inplace())
        local needToBrake = brakeDistance >= next:DistanceTo() or dot < 0.7

        -- Calculate acceleration for thrust
        local dir = (chaseData.rabbit - vehicle.position.Current()):normalize_inplace()

        local brakeLevel = 1
        if dot > 0 then
            brakeLevel = calc.Scale(dot, 0, 1, 1, 0.95)
        end

        local thrustAcc = nullVec
        if brakeAccelerationNeeded > 0 then
            thrustAcc = brakeAccelerationNeeded * -vehicle.velocity:Movement():normalize_inplace()
        elseif needToBrake then
            thrustAcc = dir * brakes:Deceleration() * 1 / brakeLevel
        else
            thrustAcc = dir * brakes:Deceleration() * brakeLevel
        end

        brakes:Set(needToBrake, brakeLevel)
        self.fsm:Thrust(thrustAcc)
    end
end

function state:Update()
end

function state:WaypointReached(isLastWaypoint, next, previous)
    if isLastWaypoint then
        self.fsm:SetState(Hold(self.fsm))
    else
        self.fsm:SetState(Travel(self.fsm))
    end
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