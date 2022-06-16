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

function state:Flush(next, previous, rabbit)
    local currentPos = construct.position.Current()
    local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance(next:DistanceTo())

    local dist = next:DistanceTo()
    -- Don't switch if we're nearly there
    if brakeDistance < dist and dist > 10 then
        self.fsm:SetState(Travel(self.fsm))
    else
        local velocity = construct.velocity:Movement()
        local travelDir = velocity:normalize()

        local toRabbit = rabbit - currentPos
        local dirToRabbit = toRabbit:normalize()
        local outOfAlignment = travelDir:dot(dirToRabbit) < 0.8

        local needToBrake = brakeDistance >= next:DistanceTo()

        brakes:Set(needToBrake or outOfAlignment)

        local acc = brakeAccelerationNeeded * -travelDir

        -- Significantly reduce acceleration when less than 1m from target.
        local mul
        if toRabbit:len() < 1 then
            mul = 0.5
        else
            mul = 2
        end
        acc = acc + (dirToRabbit + next:DirectionTo()):normalize() * mul

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