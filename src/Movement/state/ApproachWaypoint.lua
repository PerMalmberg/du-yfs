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
    local travelDir = velocity:normalize()

    brakes:Set(false)

    local dirToRabbit = (rabbit - currentPos):normalize()
    local outOfAlignment = velocity:len() >= _1kph and construct.velocity.Movement():normalize():dot(dirToRabbit) < 0.8

    local withinBrakeDistance = next:DistanceTo() <= brakeDistance

    if outOfAlignment or withinBrakeDistance then
        brakes:Set(true)

        local acc = brakeAccelerationNeeded * -travelDir
        if outOfAlignment and withinBrakeDistance then
            if travelDir:dot(construct.world.GAlongGravity():normalize()) < 0 then
                -- Going against gravity, don't counter it, but don't turn off engines completely for a quick recovery
                acc = acc + construct.world.GAlongGravity() * 0.8
            end
        end
        self.fsm:Thrust(acc)
    else
        self.fsm:Thrust(dirToRabbit)
    end
end

function state:Update()
end

function state:WaypointReached(isLastWaypoint, next, previous)
    if isLastWaypoint then
        self.fsm:SetState(Hold(self.fsm))
    else
        self.fsm:SetState(Travel(self.fsm))
    end
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