local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
local construct = require("du-libs:abstraction/Construct")()

local state = {}
state.__index = state
local name = "MoveToNearest"

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

function state:Flush(next, previous, chaseData)
    local currentPos = construct.position.Current()
    local toTarget = chaseData.nearest - currentPos

    if toTarget:len() <= next.margin then
        self.fsm:SetState(Travel(self.fsm))
    else
        local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance(toTarget:len())

        local travelDir = construct.velocity:Movement():normalize_inplace()

        brakes:Set(brakeDistance >= toTarget:len())

        local acc = brakeAccelerationNeeded * -travelDir
        if acc:len2() <= 0 then
            -- Reduce acceleration when less than 1m from target.
            local mul
            if toTarget:len() < 1 then
                mul = 1
            else
                mul = 2
            end

            acc = toTarget:normalize() * mul
        end

        self.fsm:Thrust(acc)
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