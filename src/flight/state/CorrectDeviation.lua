local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
local construct = require("du-libs:abstraction/Construct")()
local calc = require("du-libs:util/Calc")
local Velocity = construct.velocity.Movement

local state = {}
state.__index = state
local name = "CorrectDeviation"

local function new(fsm)
    checks.IsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm,
        limit = calc.Kph2Mps(3)
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
    brakes:Set(true)
end

function state:Leave()
    brakes:Set(false)
end

function state:Flush(next, previous, chaseData)
    -- Come to a near stop before moving on
    local vel = Velocity()
    local speed = Velocity():len()

    if speed < self.limit then
        self.fsm:SetState(MoveToNearest(self.fsm))
    else
        -- As the velocity goes down, so does the adjustment
        self.fsm:Thrust(-vel:normalize() * speed)
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