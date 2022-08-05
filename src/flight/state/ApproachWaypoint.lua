local r = require("CommonRequire")
local vehicle = r.vehicle
local brakes = r.brakes
local checks = r.checks
require("flight/state/Require")
local Stopwatch = require("du-libs:system/Stopwatch")

local name = "ApproachWaypoint"

local state = {}
state.__index = state

local function new(fsm)
    checks.IsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm,
        toTravel = Stopwatch()
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
    local withinLimit = brakeDistance < dist and dist > 100

    local toTravel = self.toTravel
    if withinLimit then
        if not toTravel:IsRunning() then
            toTravel:Start()
        end
    else
        toTravel:Reset()
    end

    if withinLimit and toTravel:Elapsed() > 1 then
        self.fsm:SetState(Travel(self.fsm))
    elseif not self.fsm:CheckPathAlignment(currentPos, chaseData) then
        -- Are we on the the desired path?
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