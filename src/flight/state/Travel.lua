local constants = require("du-libs:abstraction/Constants")
local vehicle = require("du-libs:abstraction/Vehicle")()
local checks = require("du-libs:debug/Checks")
local brakes = require("flight/Brakes")()
local library = require("du-libs:abstraction/Library")()
local calc = require("du-libs:util/Calc")
local nullVec = require("cpml/vec3")()
local engine = require("du-libs:abstraction/Engine")()
require("flight/state/Require")
local abs = math.abs
local min = math.min

-- Increase this to prevent engines from stopping/starting
local margin = calc.Kph2Mps(1)

local state = {}
state.__index = state

local name = "Travel"

local function new(fsm)
    checks.IsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm,
        core = library:GetCoreUnit()
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
    local currentPos = vehicle.position.Current()

    local directionToRabbit = (chaseData.rabbit - currentPos):normalize_inplace()

    if brakeDistance >= next:DistanceTo() or neededBrakeAcceleration > 0 then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    elseif not self.fsm:CheckPathAlignment(currentPos, chaseData) then
        -- Are we on the the desired path?
        self.fsm:SetState(CorrectDeviation(self.fsm))
    else

        -- Word of warning. Quickly toggling the brakes causes
        -- them to push the construct off the trajectory.

        local thrust = self:CalculateThrust(next.maxSpeed, directionToRabbit)

        self.fsm:Thrust(thrust)
    end
end

function state:CalculateThrust(maxSpeed, directionToRabbit)
    -- Compare to absolute speed
    local velocity = vehicle.velocity:Movement()
    local speedDiff = velocity:len() - maxSpeed

    if speedDiff > 0 then
        -- Need to brake
        --brakes:Set(true)
        return nullVec
    elseif speedDiff < -margin then
        -- v = v0 + a*t => a = (v - v0) / t
        -- We must not saturate the engines; giving a massive acceleration
        -- causes non-axis aligned movement to push us off the path since engines
        -- then fire with all they got which may not result in the vector we want.
        local maxAcc = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(directionToRabbit)
        local accNeeded = abs(speedDiff) / constants.PHYSICS_INTERVAL

        return directionToRabbit * min(accNeeded, maxAcc)
    else
        return nullVec
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