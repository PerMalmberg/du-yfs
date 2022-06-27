local construct = require("du-libs:abstraction/Construct")()
local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
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

    local dist = next:DistanceTo()
    -- Don't switch if we're nearly there
    if brakeDistance < dist and dist > 100 then
        self.fsm:SetState(Travel(self.fsm))
    else
        local needToBrake = brakeDistance >= next:DistanceTo()

        brakes:Set(needToBrake)

        local dir = (chaseData.rabbit - construct.position.Current()):normalize_inplace()

        local acc
        if brakeAccelerationNeeded > 0 then
            acc = brakeAccelerationNeeded * -construct.velocity:Movement():normalize_inplace()
        elseif needToBrake then
            -- Use an acceleration slightly larger than the brake force to ensure we move.
            acc = dir * brakes:Deceleration() * 1.05
        elseif dist > 1 then
            acc = dir * 1
        else
            acc = dir * 0.5
        end

        self.fsm:Thrust(acc)
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