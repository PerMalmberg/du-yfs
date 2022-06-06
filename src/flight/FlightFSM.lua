local brakes = require("flight/Brakes")()
local construct = require("abstraction/Construct")()
local calc = require("util/Calc")
local ctrl = require("abstraction/Library")():GetController()
local diag = require("debug/Diagnostics")()
local nullVec = require("cpml/vec3")()
local sharedPanel = require("panel/SharedPanel")()
local PID = require("cpml/pid")
require("flight/state/Require")
local CurrentPos = construct.position.Current

local fsm = {}
fsm.__index = fsm

local function new()
    local instance = {
        current = nil,
        wStateName = sharedPanel:Get("FlightFSM"):CreateValue("State", ""),
        wDeviation = sharedPanel:Get("FlightFSM"):CreateValue("Deviation", "m"),
        wAcceleration = sharedPanel:Get("FlightFSM"):CreateValue("Acceleration", "m/s2"),
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
        local rabbit, nearestPoint = self:NearestPointBetweenWaypoints(previous, next, pos, 6)
        diag:DrawNumber(9, rabbit)
        c:Flush(next, previous, rabbit)

        -- Add counter to deviation from optimal path
        local deviation = nearestPoint - pos
        local len = deviation:len()
        self.deviationPID:inject(len)
        self.wDeviation:Set(calc.Round((nearestPoint - pos):len(), 4))

        local maxDeviationAcc = 2
        -- If we have reached the waypoint or already are moving towards the desired optimal path, then reduce adjustment
        if next:Reached() or deviation:normalize():dot(deviation:normalize()) > 0.5 then
            maxDeviationAcc = 0.1
        end

        self.acceleration = self.acceleration + deviation:normalize() * utils.clamp(self.deviationPID:get(), 0, maxDeviationAcc)

        -- Brakes give an undesired force that pushes along/against gravity.
        --if brakes:IsEngaged() then
        --    local gVec = construct.world.GAlongGravity()
        --    if gVec:len2() > 0 then
        --        local dot = construct.velocity.Movement():normalize_inplace():dot(gVec:normalize())
        --        if dot > -0.7 and dot < 0.7 then
        --            self.acceleration = self.acceleration + brakes:Deceleration() * dot * construct.velocity.Movement():normalize_inplace()
        --        end
        --    end
        --end
    end

    if self.acceleration == nil then
        diag:RemoveNumber(0)
        diag:RemoveNumber(9)
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
        self.wAcceleration:Set(construct.acceleration.Movement():len())
        c:Update()
    end
end

function fsm:WaypointReached(isLastWaypoint, next, previous)
    if self.current ~= nil then
        self.current:WaypointReached(isLastWaypoint, next, previous)
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
    local point = nearestPoint + dir * ahead
    local remaining = wpEnd.destination - point

    -- Is the point past the end (remaining points back towards start or we're very close to the destination)?
    if remaining:normalize():dot(dir) < 1 or remaining:len() < 0.01 then
        return wpEnd.destination, nearestPoint
    else
        return point, nearestPoint
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