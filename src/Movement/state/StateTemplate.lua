local diag = require("Diagnostics")()

local state = {}
state.__index = state

local function new(fsm)
    diag:AssertIsTable(fsm, "fsm", "NameOfState:new")

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

function state:Flush(waypoint, previousWaypoint)
end

function state:Update()
end

function state:Name()
    return "StateTemplate"
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