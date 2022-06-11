local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
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
    brakes:Set(true)
end

function state:Leave()

end

function state:Flush(next, previous, rabbit)
    if not next:Reached() then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    else
        self.fsm:Thrust() -- Just counter gravity
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