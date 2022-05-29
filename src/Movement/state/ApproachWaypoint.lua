local construct = require("abstraction/Construct")()
local brakes = require("Brakes")()
local diag = require("Diagnostics")()

local state = {}
state.__index = state

local function new(fsm)
    diag:AssertIsTable(fsm, "fsm", "ApproachWaypoint:new")

    local o = {
        fsm = fsm
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
end

function state:Leave()
    brakes:Set(false)
end

function state:Flush(waypoint, previousWaypoint)
    local currentPos = construct.position.Current()
    local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance()

    -- Brake as long as needed
    if waypoint:DistanceTo() <= brakeDistance then
        brakes:Set(true)
        self.fsm:Thrust(brakeAccelerationNeeded * -construct.velocity:Movement():normalize())
    end

    -- Use 1m/s acceleration

    -- Follow nearest point

end

function state:Update()
end

function state:Name()
    return "ApproachWaypoint"
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