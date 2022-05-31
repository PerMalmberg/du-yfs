local construct = require("abstraction/Construct")()
local brakes = require("Brakes")()
local diag = require("Diagnostics")()
local calc = require("Calc")
local nullVec = require("cpml/vec3")()

local name = "ApproachWaypoint"
local _1kph = calc.Kph2Mps(1)

local state = {}
state.__index = state

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

function state:Flush(next, previous, rabbit)
    local currentPos = construct.position.Current()
    local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance()
    local velocity = construct.velocity:Movement()

    brakes:Set(false)

    if next:Reached() then
        self.fsm:SetState(Hold(self.fsm))
    else
        local dirToRabbit = (rabbit - currentPos):normalize()
        local outOfAlignment = velocity:len() >= _1kph and construct.velocity.Movement():normalize():dot(dirToRabbit) < 0.8

        if outOfAlignment or next:DistanceTo() <= brakeDistance then
            brakes:Set(true)
            self.fsm:Thrust(brakeAccelerationNeeded * -velocity:normalize())
        else
            self.fsm:Thrust(dirToRabbit)
        end
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