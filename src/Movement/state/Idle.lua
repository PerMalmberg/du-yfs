local diag = require("Diagnostics")()

local state = {}
state.__index = state

local name = "Idle"

local function new(fsm)
    diag:AssertIsTable(fsm, "fsm", name .. ":new")
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