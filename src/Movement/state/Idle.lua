local diag = require("Diagnostics")()

local state = {}
state.__index = state

local function new(fsm)
    diag:AssertIsTable(fsm, "fsm", "Idle:new")
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
    self.fsm:NullThrust()
end

function state:Update()
end

function state:Name()
    return "Idle"
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