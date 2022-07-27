local vehicle = require("du-libs:abstraction/Vehicle")()
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
    local brakeDistance, _ = brakes:BrakeDistance(next:DistanceTo())
    local currentPos = vehicle.position.Current()

    local dist = next:DistanceTo()
    -- Don't switch if we're nearly there
    if brakeDistance < dist and dist > 1000 then
        self.fsm:SetState(Travel(self.fsm))
    elseif not self.fsm:CheckPathAlignment(currentPos, chaseData) then
        -- Are we on the the desired path?
        self.fsm:Thrust()
        self.fsm:SetState(ReturnToPath(self.fsm, chaseData.nearest))
    else
        self.fsm:Move((chaseData.rabbit - currentPos):normalize_inplace(), dist, next.maxSpeed)
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