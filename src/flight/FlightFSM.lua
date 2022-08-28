local r = require("CommonRequire")
local brakes = r.brakes
local vehicle = r.vehicle
local world = vehicle.world
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
local Stopwatch = require("du-libs:system/Stopwatch")
require("flight/state/Require")
local CurrentPos = vehicle.position.Current
local Velocity = vehicle.velocity.Movement
local Acceleration = vehicle.acceleration.Movement
local utils = require("cpml/utils")
local clamp = utils.clamp
local abs = math.abs
local min = math.min
local max = math.max

local longitudinal = "longitudinal"
local vertical = "vertical"
local lateral = "lateral"
local airfoil = "airfoil"
local thrustTag = "thrust"
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
        engines = EngineGroup(thrustTag, airfoil),
        prio1Tag = airfoil,
        prio2Tag = thrustTag,
        prio3Tag = "",
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
    thrust = { engines = EngineGroup(longitudinal),
               prio1Tag = thrustTag,
               prio2Tag = "",
               prio3Tag = "",
               antiG = NoAntiG
    },
    adjust = { engines = EngineGroup(airfoil, lateral, vertical),
               prio1Tag = airfoil,
               prio2Tag = lateral,
               prio3Tag = vertical,
               antiG = AntiG
    }
}

local rightGroup = {
    thrust = { engines = EngineGroup(lateral),
               prio1Tag = thrustTag,
               prio2Tag = "",
               prio3Tag = "",
               antiG = NoAntiG
    },
    adjust = { engines = EngineGroup(vertical, longitudinal),
               prio1Tag = vertical,
               prio2Tag = longitudinal,
               prio3Tag = "",
               antiG = AntiG
    }
}

local upGroup = {
    thrust = { engines = EngineGroup(vertical),
               prio1Tag = vertical,
               prio2Tag = "",
               prio3Tag = "",
               antiG = AntiG
    },
    adjust = { engines = EngineGroup(lateral, longitudinal),
               prio1Tag = vertical,
               prio2Tag = longitudinal,
               prio3Tag = "",
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

local thrustAccLookup = {
    { limit = 0, acc = 0.10, reverse = 0.10 },
    { limit = 0.2, acc = 0.20, reverse = 1 },
    { limit = 0.8, acc = 0.30, reverse = 1 },
    { limit = 2.0, acc = 0, reverse = 0 }
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
        wTargetSpeed = p:CreateValue("Target speed", "km/h"),
        wSpeed = p:CreateValue("Abs. speed", "km/h"),
        wAdjTowards = p:CreateValue("Adj. towards"),
        wAdjDist = p:CreateValue("Adj. distance", "m"),
        wAdjAcc = p:CreateValue("Adj. acc", "m/s2"),
        wAdjBrakeDistance = p:CreateValue("Adj. brake dist.", "m"),
        wAdjSpeed = p:CreateValue("Adj. speed (limit)", "m/s"),
        acceleration = nil,
        adjustAcc = nullVec,
        lastDevDist = 0,
        currentDeviation = nullVec,
        deviationAccum = Accumulator:New(10, Accumulator.Truth),
        delta = Stopwatch()
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
    local delta = self.delta
    local deltaTime = 0
    if delta:IsRunning() then
        deltaTime = delta:Elapsed()
        delta:Restart()
    else
        delta:Start()
    end


    local c = self.current
    if c ~= nil then
        local pos = CurrentPos()
        local chaseData = self:NearestPointBetweenWaypoints(previous, next, pos, 6)

        brakes:Set(false)

        -- Assume we're just going to counter gravity.
        self.acceleration = nullVec
        self.adjustAcc = nullVec

        c:Flush(deltaTime, next, previous, chaseData)
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
function fsm:Move(deltaTime, direction, remainingDistance, maxSpeed, rampFactor)
    if direction:len() == 0 then
        -- Exactly on the target
        self:Thrust()
        return
    end

    local vel = Velocity()

    -- Look ahead at where we will be next tick. If we're decelerating, don't allow values less than 0
    remainingDistance = remainingDistance + vel:len() * deltaTime + 0.5 * Acceleration():len() * deltaTime * deltaTime

    local travelDir = vel:normalize()

    if travelDir:len() <= 0 then
        -- No velocity so set it to the direction we want to go.
        travelDir = direction
    end

    self.wPointDistance:Set(calc.Round(remainingDistance, 4))

    local gravInfluence = abs((universe:VerticalReferenceVector() * world.G()):dot(-travelDir))


    -- Calculate max speed we may have with available brake force to come to a stop at the target
    -- Might not be enough brakes or engines to counter gravity so don't go below 0
    local brakeAcc = max(0, brakes:Deceleration() - gravInfluence)

    local currentSpeed = vel:len()

    local function ScaleForWarmup()
        local warmupDistance = currentSpeed * self:GetEngineWarmupTime()
        if remainingDistance <= 0 or warmupDistance <= 0 then
            return 1
        end

        return clamp(5 * warmupDistance / remainingDistance, 0, 1)
    end

    -- Gravity is already taken care of for engines
    local engineAcc = max(0, engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-travelDir))

    local function CalcMaxSpeed(acceleration, distance)
        -- v^2 = v0^2 + 2a*d, with V0=0 => v = sqrt(2a*d)
        return (2 * acceleration * distance) ^ 0.5
    end

    local engineMaxSpeed = CalcMaxSpeed(engineAcc * ScaleForWarmup(), remainingDistance)

    -- When we're standing still we get no brake speed since brakes gives no force (in atmosphere)
    local brakeMaxSpeed = CalcMaxSpeed(brakeAcc, remainingDistance)-- * 0.6 -- QQQ Brake efficiency

    -- Assume neither brake nor engine can brake us so default to 1 km/h.
    -- Setting it to zero locks construct in place.
    local targetSpeed = calc.Kph2Mps(1)

    if brakeMaxSpeed > 0 or engineMaxSpeed > 0 then
        if world.IsInAtmo() and vel:len() < calc.Kph2Mps(360) then
            -- Atmospheric brakes start giving less force at this speed, rely on engines
            targetSpeed = engineMaxSpeed
        else
            -- Prefer the method with highest speed; i.e. shortest brake distance
            targetSpeed = max(brakeMaxSpeed, engineMaxSpeed)
        end
    end

    targetSpeed = min(maxSpeed, targetSpeed)

    -- Help come to a stop if we're going in the wrong direction
    if travelDir:dot(direction) < 0 then
       targetSpeed = 0
    end

    self.wTargetSpeed:Set(calc.Round(calc.Mps2Kph(targetSpeed), 2))

    if currentSpeed > targetSpeed then
        -- Going too fast
        brakes:Set(true, "Reduce speed")
        local thrust = Vec3()
        if direction:dot(travelDir) > 0 then
            -- Moving towards point, brake
            thrust = -travelDir * getAdjustedAcceleration(thrustAccLookup, -travelDir, remainingDistance, true, true)
        else
            -- Moving away from point, accelerate towards it
            thrust = direction * getAdjustedAcceleration(thrustAccLookup, direction, remainingDistance, false, true)
        end
        self:Thrust(thrust)
    elseif targetSpeed - currentSpeed > speedMargin then
        -- We must not saturate the engines; giving a massive acceleration
        -- causes non-axis aligned movement to push us off the path since engines
        -- then fire with all they got which may not result in the vector we want.
        local acc = getAdjustedAcceleration(thrustAccLookup, direction, remainingDistance, true, true)
        self:Thrust(direction * acc * (rampFactor or 1))
    else
        -- Just counter gravity.
        self:Thrust()
    end
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
        local groups = self:GetEngines(moveDirection, precision)
        local t = groups.thrust
        local a = groups.adjust
        local thrustAcc = self.acceleration + t.antiG() - Vec3(construct.getWorldAirFrictionAcceleration())
        local adjustAcc = (self.adjustAcc or nullVec) + a.antiG()

        if precision then
            -- Apply acceleration independently
            ctrl.setEngineCommand(t.engines:Intersection(), { thrustAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 0.001)
            ctrl.setEngineCommand(a.engines:Union(), { adjustAcc:unpack() }, { 0, 0, 0 }, 1, 1, a.prio1Tag, a.prio2Tag, a.prio3Tag, 0.001)
        else
            -- Apply acceleration as a single vector
            local finalAcc = thrustAcc + adjustAcc
            ctrl.setEngineCommand(t.engines:Union(), { finalAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 0.001)
        end
    end
end

function fsm:Update()
    local c = self.current
    if c ~= nil then
        self.wAcceleration:Set(calc.Round(Acceleration():len(), 2))
        self.wSpeed:Set(calc.Round(calc.Mps2Kph(Velocity():len()), 1))
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