local constants = require("du-libs:abstraction/Constants")
local vehicle = require("du-libs:abstraction/Vehicle")()
local checks = require("du-libs:debug/Checks")
local brakes = require("flight/Brakes")()
local Vec3 = require("cpml/vec3")
local library = require("du-libs:abstraction/Library")()
local calc = require("du-libs:util/Calc")
require("flight/state/Require")
local abs = math.abs

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
    local velocity = vehicle.velocity:Movement()
    local currentPos = vehicle.position.Current()

    local directionToRabbit = (chaseData.rabbit - currentPos):normalize_inplace()

    if brakeDistance >= next:DistanceTo() or neededBrakeAcceleration > 0 then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    else
        -- Word of warning. Quickly toggling the brakes causes
        -- them to push the construct off the trajectory.

        -- Get speed diff in direction of rabbit
        local currentSpeed = velocity:dot(directionToRabbit)
        local speedDiff = currentSpeed - next.maxSpeed

        if speedDiff > 0 then
            -- Need to brake
            brakes:Set(true)
            self.fsm:Thrust()
        elseif speedDiff < -margin then
            -- v = v0 + a*t => a = (v - v0) / t
            -- Accelerate with whatever power would be needed and is available.
            local accNeeded = abs(speedDiff) / constants.PHYSICS_INTERVAL
            self.fsm:Thrust(directionToRabbit * accNeeded - Vec3(construct.getWorldAirFrictionAcceleration()))
        else
            self.fsm:Thrust(-Vec3(construct.getWorldAirFrictionAcceleration()))
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