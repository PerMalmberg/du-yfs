require("movement/state/Require")
local sharedPanel = require("panel/SharedPanel")()
local construct = require("abstraction/Construct")()
local library = require("abstraction/Library")()
local calc = require("Calc")
local nullVec = require("cpml/vec3")()
local diag = require("Diagnostics")()
local PID = require("cpml/PID")
local ctrl = library.GetController()
local CurrentPos = construct.position.Current

local fsm = {}
fsm.__index = fsm

local function new()
    local instance = {
        current = nil,
        wStateName = sharedPanel:Get("FlightFSM"):CreateValue("State", ""),
        wDeviation = sharedPanel:Get("FlightFSM"):CreateValue("Deviation", "m"),
        nearestPoint = nil,
        acceleration = nil,
        deviationPID = PID(0, 0.8, 0.2, 0.5),
    }
    setmetatable(instance, fsm)
    instance:SetState(Idle(instance))
    return instance
end

function fsm:Flush(next, previous)
    local c = self.current

    local pos = CurrentPos()

    if c ~= nil then
        local rabbit = self:NearestPointBetweenWaypoints(previous, next, pos, 3)
        diag:DrawNumber(3, rabbit)
        c:Flush(next, previous, rabbit)

        -- Add counter to deviation from desired path
        local deviation = rabbit - pos
        local len = deviation:len()
        self.deviationPID:inject(len)
        self.wDeviation:Set(calc.Round(len, 4))
        self.acceleration = self.acceleration + deviation:normalize() * utils.clamp(self.deviationPID:get(), 0, 2)
    end

    if self.acceleration == nil then
        diag:RemoveNumber(0)
        self:NullThrust()
        self.deviationPID:inject(0) -- reset PID
    else
        diag:DrawNumber(0, pos + self.acceleration:normalize() * 8)
        ctrl.setEngineCommand("thrust", { self.acceleration:unpack() })
    end
end

function fsm:Update()
    local c = self.current
    if c ~= nil then
        c:Update()
    end
end

function fsm:SetState(state)
    if self.current ~= nil then
        self.current:Leave()
    end

    if state == nil then
        self.wStateName:Set("No state!")
    else
        self.wStateName:Set(state:Name())
        state:Enter()
    end

    self.current = state
end

function fsm:DisableThrust()
    self.acceleration = nil
end

function fsm:Thrust(acceleration)
    acceleration = acceleration or nullVec
    -- Compensate for any gravity
    self.acceleration = acceleration - construct.world.GAlongGravity()
end

function fsm:NullThrust()
    ctrl.setEngineCommand("thrust", { 0, 0, 0 })
end

function fsm:NearestPointBetweenWaypoints(wpStart, wpEnd, currentPos, ahead)
    local totalDiff = wpEnd.destination - wpStart.destination
    local dir = totalDiff:normalize()
    local nearestPoint = calc.NearestPointOnLine(wpStart.destination, dir, currentPos)

    ahead = (ahead or 0)
    nearestPoint = nearestPoint + dir * ahead
    local remaining = wpEnd.destination - nearestPoint

    -- Is the point past the end (remaining points back towards start or we're very close to the destination)?
    if remaining:normalize():dot(dir) < 1 or remaining:len() < 0.01 then
        return wpEnd.destination
    else
        return nearestPoint
    end
end

-- The module
return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                return new()
            end
        }
)