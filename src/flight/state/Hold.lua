local r = require("CommonRequire")
local brakes = r.brakes
local checks = r.checks
require("flight/state/Require")

local state = {}
state.__index = state

local name = "Hold"

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

function state:Flush(deltaTime, next, previous, chaseData)
    if next.Reached() then
        next:SetPrecisionMode(true)
    else
        self.fsm:SetState(Travel(self.fsm))
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
