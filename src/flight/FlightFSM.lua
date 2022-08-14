local r = require("CommonRequire")
local brakes = r.brakes
local vehicle = r.vehicle
local calc = r.calc
local CalcBrakeAcceleration = calc.CalcBrakeAcceleration
local CalcBrakeDistance = calc.CalcBrakeDistance
local universe = r.universe
local Vec3 = r.Vec3
local nullVec = Vec3()
local ctrl = r.library:GetController()
local visual = r.visual
local sharedPanel = require("du-libs:panel/SharedPanel")()
local engine = r.engine
local EngineGroup = require("du-libs:abstraction/EngineGroup")
local Accumulator = require("du-libs:util/Accumulator")
local PID = require("cpml/pid")
require("flight/state/Require")
local CurrentPos = vehicle.position.Current
local Velocity = vehicle.velocity.Movement
local Acceleration = vehicle.acceleration.Movement
local abs = math.abs
local min = math.min

local longitudinal = "longitudinal"
local vertical = "vertical"
local lateral = "lateral"
local airfoil = "airfoil"
local thrustTag = "thrust"
local brakeTag = "brake"
local Forward = vehicle.orientation.Forward
local Right = vehicle.orientation.Right

local AntiG = function()
    return -universe:VerticalReferenceVector() * vehicle.world.G()
end

local NoAntiG = function()
    return nullVec
end

local normalModeGroup = {
    thrust = {
        engines = EngineGroup(brakeTag, thrustTag, airfoil),
        prio1Tag = brakeTag,
        prio2Tag = airfoil,
        prio3Tag = thrustTag,
        antiG = AntiG
    },
    adjust = { engines = EngineGroup(),
               prio1Tag = "",
               prio2Tag = "",
               prio3Tag = "",
               antiG = NoAntiG
    }
}

local forwardGroup = {
    thrust = { engines = EngineGroup(brakeTag, longitudinal),
               prio1Tag = brakeTag,
               prio2Tag = thrustTag,
               prio3Tag = "",
               antiG = NoAntiG
    },
    adjust = { engines = EngineGroup(brakeTag, lateral, vertical),
               prio1Tag = brakeTag,
               prio2Tag = lateral,
               prio3Tag = vertical,
               antiG = AntiG
    }
}

local rightGroup = {
    thrust = { engines = EngineGroup(brakeTag, lateral),
               prio1Tag = brakeTag,
               prio2Tag = thrustTag,
               prio3Tag = "",
               antiG = NoAntiG
    },
    adjust = { engines = EngineGroup(brakeTag, vertical, longitudinal),
               prio1Tag = brakeTag,
               prio2Tag = vertical,
               prio3Tag = longitudinal,
               antiG = AntiG
    }
}

local upGroup = {
    thrust = { engines = EngineGroup(brakeTag, vertical),
               prio1Tag = brakeTag,
               prio2Tag = vertical,
               prio3Tag = "",
               antiG = AntiG
    },
    adjust = { engines = EngineGroup(brakeTag, lateral, longitudinal),
               prio1Tag = brakeTag,
               prio2Tag = vertical,
               prio3Tag = longitudinal,
               antiG = NoAntiG
    }
}

local toleranceDistance = 2 -- meters. This limit affects the steepness of the acceleration curve used by the deviation adjustment
local adjustmentSpeedMin = calc.Kph2Mps(0.5)
local adjustmentSpeedMax = calc.Kph2Mps(50)
local speedMargin = calc.Kph2Mps(0.5)
local warmupTime = 1

local adjustAccLookup = {
    { limit = 0, acc = 0.15, reverse = 0.3 },
    { limit = 0.01, acc = 0.20, reverse = 0.35 },
    { limit = 0.03, acc = 0.30, reverse = 0.40 },
    { limit = 0.05, acc = 0.40, reverse = 0.45 },
    { limit = 0.1, acc = 0, reverse = 0 }
}



local getAdjustedAcceleration = function(accLookup, dir, distance, movingTowardsTarget, forThrust)
    local selected
    for _, v in ipairs(accLookup) do
        if distance >= v.limit then selected = v
        else break end
    end

    if selected.acc == 0 then
        local warmupDistance = warmupTime * Velocity():len()
        if forThrust and distance <= warmupDistance then
            return accLookup[#accLookup - 1].acc
        else
            return engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(dir)
        end
    else
        return calc.Ternary(movingTowardsTarget, selected.acc, selected.reverse)
    end
end

local fsm = {}
fsm.__index = fsm

local function new(settings)

    local p = sharedPanel:Get("Movement")

    local instance = {
        current = nil,
        wStateName = p:CreateValue("State", ""),
        wPointDistance = p:CreateValue("Point dist.", "m"),
        wAcceleration = p:CreateValue("Acceleration", "m/s2"),
        wSpeed = p:CreateValue("Abs. speed", "m/s"),
        wAdjTowards = p:CreateValue("Adj. towards"),
        wAdjDist = p:CreateValue("Adj. distance", "m"),
        wAdjAcc = p:CreateValue("Adj. acc", "m/s2"),
        wAdjBrakeDistance = p:CreateValue("Adj. brake dist.", "m"),
        wAdjSpeed = p:CreateValue("Adj. speed (limit)", "m/s"),
        acceleration = nil,
        adjustAcc = nullVec,
        lastDevDist = 0,
        currentDeviation = nullVec,
        deviationAccum = Accumulator:New(10),
        speedPid = PID(1, 0.001, 1)
    }

    setmetatable(instance, fsm)
    instance:SetState(Idle(instance))

    settings:RegisterCallback("engineWarmup", function(value)
        instance:SetEngineWarmupTime(value)
        brakes:SetEngineWarmupTime(value)
    end)

    return instance
end

function fsm:SetEngineWarmupTime(t)
    warmupTime = t
end

function fsm:GetEngineWarmupTime()
    return warmupTime
end

function fsm:GetEngines(moveDirection, precision)
    if precision then
        if abs(moveDirection:dot(Forward())) >= 0.707 then
            return forwardGroup
        elseif abs(moveDirection:dot(Right())) >= 0.707 then
            return rightGroup
        else
            return upGroup
        end
    else
        return normalModeGroup
    end
end

function fsm:CheckPathAlignment(currentPos, chaseData)
    local res = true

    local vel = Velocity()
    local speed = vel:len()

    local toNearest = chaseData.nearest - currentPos

    if speed > 1 then
        res = toNearest:len() < toleranceDistance
    end

    return res
end

function fsm:FsmFlush(next, previous)
    local c = self.current
    if c ~= nil then
        local pos = CurrentPos()
        local chaseData = self:NearestPointBetweenWaypoints(previous, next, pos, 6)

        brakes:Set(false)

        -- Assume we're just going to counter gravity.
        self.acceleration = nullVec
        self.adjustAcc = nullVec

        c:Flush(next, previous, chaseData)
        local moveDirection

        if c.OverrideAdjustPoint then
            chaseData.nearest = c:OverrideAdjustPoint()
            moveDirection = (chaseData.nearest - pos):normalize_inplace()
        else
            moveDirection = next:DirectionTo()
        end

        self:AdjustForDeviation(chaseData, pos, moveDirection)

        self:ApplyAcceleration(moveDirection, next:GetPrecisionMode())

        visual:DrawNumber(9, chaseData.rabbit)
        visual:DrawNumber(8, chaseData.nearest)
        visual:DrawNumber(0, pos + (self.acceleration or nullVec):normalize() * 8)
    else
        self:ApplyAcceleration(nullVec, false)
    end
end

---@param direction Vec3 The direction to travel
---@param remainingDistance number The remaining distance
---@param maxSpeed number Maximum speed, m/s
---@param rampFactor number 0..1 A factor that limits the amount of thrust we may apply.
function fsm:Move(direction, remainingDistance, maxSpeed, rampFactor)
    local vel = Velocity()
    local travelDir = vel:normalize()
    local currentSpeed = vel:len()

    self.wPointDistance:Set(calc.Round(remainingDistance, 4))

    -- Calculate max speed we may have with available brake force to come to a stop at the target
    local brakeForce = brakes:Deceleration() + brakes:GravityInfluence()
    local engineForce = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-travelDir)
    -- v^2 = v0^2 + 2a*d, with V0=0 => v = sqrt(2a*d)
    local CalcMaxSpeed = function(a, d)
        return math.sqrt(2*a*d)
    end

    local brakeSpeed = CalcMaxSpeed(brakeForce, remainingDistance)
    local engineSpeed = CalcMaxSpeed(engineForce, remainingDistance)
    local targetSpeed = min(maxSpeed, brakeSpeed, engineSpeed)

    local speedDiff =  targetSpeed - currentSpeed

    self.speedPid:inject(speedDiff)

    local thrust = self.speedPid:get()
    local sign = calc.Sign(thrust)
    if sign ~= 0 then
        --local availableAcc = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(sign * direction)
        --thrust = sign * min(availableAcc, abs(value))
    end

    system.print(speedDiff .. " " .. brakeSpeed .. " " .. engineSpeed .. " " .. targetSpeed .. " " .. maxSpeed)
    self:Thrust(direction * thrust)
end

function fsm:CurrentDeviation()
    return self.currentDeviation
end

function fsm:AdjustForDeviation(chaseData, currentPos, moveDirection)
    -- Add counter to deviation from optimal path
    local plane = moveDirection:normalize()
    local vel = calc.ProjectVectorOnPlane(plane, Velocity())
    local currSpeed = vel:len()

    local targetPoint = chaseData.nearest

    local toTargetWorld = targetPoint - currentPos
    local toTarget = calc.ProjectPointOnPlane(plane, currentPos, chaseData.nearest) - calc.ProjectPointOnPlane(plane, currentPos, currentPos)
    local dirToTarget = toTarget:normalize()
    local distance = toTarget:len()
    self.currentDeviation = toTarget

    local movingTowardsTarget = self.deviationAccum:Add(vel:normalize():dot(dirToTarget) > 0.8) > 0.5

    local maxBrakeAcc = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-toTargetWorld:normalize())
    local brakeDistance = CalcBrakeDistance(currSpeed, maxBrakeAcc) + warmupTime * currSpeed
    local speedLimit = calc.Scale(distance, 0, toleranceDistance, adjustmentSpeedMin, adjustmentSpeedMax)

    self.wAdjTowards:Set(movingTowardsTarget)
    self.wAdjDist:Set(calc.Round(distance, 4))
    self.wAdjBrakeDistance:Set(calc.Round(brakeDistance))
    self.wAdjSpeed:Set(calc.Round(currSpeed, 1) .. "(" .. calc.Round(speedLimit, 1) .. ")")

    if distance > 0 then
        -- Are we moving towards target?
        if movingTowardsTarget then
            if brakeDistance > distance or currSpeed > speedLimit then
                self.adjustAcc = -dirToTarget * CalcBrakeAcceleration(currSpeed, distance)
            elseif distance > self.lastDevDist then
                -- Slipping away, nudge back to path
                self.adjustAcc = dirToTarget * getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
            elseif distance < toleranceDistance then
                -- Add brake acc to help stop where we want
                self.adjustAcc = -dirToTarget * CalcBrakeAcceleration(currSpeed, distance)
            elseif currSpeed < speedLimit then
                -- This check needs to be last so that it doesn't interfere with decelerating towards destination
                self.adjustAcc = dirToTarget * getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
            end
        else
            -- Counter current movement, if any
            if currSpeed > 0.1 then
                self.adjustAcc = -vel:normalize() * getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
            else
                self.adjustAcc = dirToTarget * getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
            end
        end
    else
        self.adjustAcc = nullVec
    end

    self.lastDevDist = distance

    self.wAdjAcc:Set(calc.Round(self.adjustAcc:len(), 2))
end

function fsm:ApplyAcceleration(moveDirection, precision)
    if self.acceleration == nil then
        ctrl.setEngineCommand(thrustTag, { 0, 0, 0 }, { 0, 0, 0 }, 1, 1, "", "", "", 0.001)
    else
        local thrustAcc = self.acceleration
        ctrl.setEngineCommand("brake thrust", { thrustAcc:unpack() }, { 0, 0, 0 }, 1, 1, "brake", "thrust", "", 0.001)

        --local groups = self:GetEngines(moveDirection, precision)
        --local t = groups.thrust
        --local a = groups.adjust
        --local thrustAcc = self.acceleration + t.antiG() - Vec3(construct.getWorldAirFrictionAcceleration())
        --local adjustAcc = (self.adjustAcc or nullVec) + a.antiG()
        --
        --if precision then
        --    -- Apply acceleration independently
        --    ctrl.setEngineCommand(t.engines:Intersection(), { thrustAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 0.001)
        --    ctrl.setEngineCommand(a.engines:Union(), { adjustAcc:unpack() }, { 0, 0, 0 }, 1, 1, a.prio1Tag, a.prio2Tag, a.prio3Tag, 0.001)
        --else
        --    -- Apply acceleration as a single vector
        --    local finalAcc = thrustAcc + adjustAcc
        --    ctrl.setEngineCommand(t.engines:Union(), { finalAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 0.001)
        --end
    end
end

function fsm:Update()
    local c = self.current
    if c ~= nil then
        self.wAcceleration:Set(calc.Round(Acceleration():len(), 2))
        self.wSpeed:Set(calc.Round(Velocity():len(), 2))
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
    self.adjustAcc = nil
end

function fsm:Thrust(acceleration)
    self.acceleration = acceleration or nullVec
end

function fsm:NullThrust()
    self.acceleration = nullVec
    self.adjustAcc = nullVec
end

function fsm:NearestPointBetweenWaypoints(wpStart, wpEnd, currentPos, ahead)
    local totalDiff = wpEnd.destination - wpStart.destination
    local dir = totalDiff:normalize()
    local nearestPoint = calc.NearestPointOnLine(wpStart.destination, dir, currentPos)

    ahead = (ahead or 0)
    local startDiff = nearestPoint - wpStart.destination
    local distanceFromStart = startDiff:len()
    local rabbitDistance = min(distanceFromStart + ahead, totalDiff:len())
    local rabbit = wpStart.destination + dir * rabbitDistance

    if startDiff:normalize():dot(dir) < 0 then
        return { nearest = wpStart.destination, rabbit = rabbit }
    elseif startDiff:len() >= totalDiff:len() then
        return { nearest = wpEnd.destination, rabbit = rabbit }
    else
        return { nearest = nearestPoint, rabbit = rabbit }
    end
end

-- The module
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