local vehicle = require("du-libs:abstraction/Vehicle")()
local checks = require("du-libs:debug/Checks")
local brakes = require("flight/Brakes")()
local library = require("du-libs:abstraction/Library")()
require("flight/state/Require")
local CurrentPos = vehicle.position.Current

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
    local currentPos = CurrentPos()

    local directionToRabbit = (chaseData.rabbit - currentPos):normalize_inplace()

    if brakeDistance >= next:DistanceTo() or neededBrakeAcceleration > 0 then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    elseif not self.fsm:CheckPathAlignment(currentPos, chaseData) then
        -- Are we on the the desired path?
        self.fsm:SetState(ReturnToPath(self.fsm, chaseData.nearest))
    else
        -- QQQ Ramp up the acceleration based engine warmup to prevent getting off path.
        self.fsm:Move(directionToRabbit, next:DistanceTo(), next.maxSpeed)
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