local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
local construct = require("du-libs:abstraction/Construct")()

local state = {}
state.__index = state
local name = "MoveToNearest"

local function new(fsm)
    checks.IsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm,
        target = nil
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
end

function state:Leave()
end

function state:Flush(next, previous, chaseData)
    -- Capture the nearest position when w
    if self.target == nil then
        self.target = chaseData.nearest
    end

    local currentPos = construct.position.Current()
    local toTarget = self.target - currentPos

    if toTarget:len() <= next.margin then
        self.fsm:SetState(Travel(self.fsm))
    else
        local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance(toTarget:len())

        local travelDir = construct.velocity:Movement():normalize_inplace()

        brakes:Set(brakeDistance >= toTarget:len())

        local acc = brakeAccelerationNeeded * -travelDir
        if acc:len2() <= 0 then
            -- Significantly reduce acceleration when less than 1m from target.
            local mul
            if toTarget:len() < 1 then
                mul = 0.5
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