local diag = require("Diagnostics")()
local brakes = require("Brakes")()
local construct = require("abstraction/Construct")()

local state = {}
state.__index = state

local name = "Hold"

local function new(fsm)
    diag:AssertIsTable(fsm, "fsm", name .. ":new")

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
    brakes:Set(false)
end

function state:Flush(next, previous, rabbit)
    if not next:Reached() then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    end
end

function state:Update()
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