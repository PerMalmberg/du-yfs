local construct = require("abstraction/Construct")()
local brakes = require("Brakes")()
local diag = require("Diagnostics")()
local nullVec = require("cpml/vec3")()

local state = {}
state.__index = state

local name = "ApproachWaypoint"

local function new(fsm)
    diag:AssertIsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
    brakes:Set(false)
end

function state:Leave()

end

function state:Flush(next, previous)
    local currentPos = construct.position.Current()
    local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance()
    local rabbit = self.fsm:NearestPointBetweenWaypoints(previous, next, currentPos, 3)

    diag:DrawNumber(3, rabbit)

    local acceleration = nullVec
    brakes:Set(false)

    if next:Reached() then
        self.fsm:SetState(Hold(self.fsm))
    else
        if next:DistanceTo() <= brakeDistance then
            brakes:Set(true)
            acceleration = brakeAccelerationNeeded * -construct.velocity:Movement():normalize()
        end

        self.fsm:Thrust(acceleration + (rabbit - currentPos):normalize_inplace() * 1)
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