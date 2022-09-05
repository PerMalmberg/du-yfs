local r = require("CommonRequire")
local log = r.log
local brakes = r.brakes
local vehicle = r.vehicle
local world = vehicle.world
local calc = r.calc
local CalcBrakeAcceleration = calc.CalcBrakeAcceleration
local CalcBrakeDistance = calc.CalcBrakeDistance
local Ternary = calc.Ternary
local universe = r.universe
local Vec3 = r.Vec3
local nullVec = Vec3()
local ctrl = r.library:GetController()
local visual = r.visual
local sharedPanel = require("panel/SharedPanel")()
local engine = r.engine
local EngineGroup = require("abstraction/EngineGroup")
local Accumulator = require("util/Accumulator")
local Stopwatch = require("system/Stopwatch")
local PID = require("cpml/pid")
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
local warmupTime = 1
local brakeEfficiencyFactor = 0.6

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
    local a = sharedPanel:Get("Adjustment")

    local instance = {
        current = nil,
        wStateName = p:CreateValue("State", ""),
        wPointDistance = p:CreateValue("Point dist.", "m"),
        wAcceleration = p:CreateValue("Acceleration", "m/s2"),
        wTargetSpeed = p:CreateValue("Target speed", "km/h"),
        wBrakeMaxSpeed = p:CreateValue("Brake Max Speed", "km/h"),
        wEngineMaxSpeed = p:CreateValue("Engine Max Speed", "km/h"),
        wSpeed = a:CreateValue("Abs. speed", "km/h"),
        wAdjTowards = a:CreateValue("Adj. towards"),
        wAdjDist = a:CreateValue("Adj. distance", "m"),
        wAdjAcc = a:CreateValue("Adj. acc", "m/s2"),
        wAdjBrakeDistance = a:CreateValue("Adj. brake dist.", "m"),
        wAdjSpeed = a:CreateValue("Adj. speed (limit)", "m/s"),
        currentWP = nil,
        acceleration = nil,
        adjustAcc = nullVec,
        lastDevDist = 0,
        currentDeviation = nullVec,
        deviationAccum = Accumulator:New(10, Accumulator.Truth),
        delta = Stopwatch(),
        --speedPid = PID(0.01, 0.001, 0.0) -- Large
        speedPid = PID(0.08, 0.0005, 0.1), -- Small
    }

    setmetatable(instance, fsm)
    instance:SetState(Idle(instance))

    settings:RegisterCallback("engineWarmup", function(value)
        instance:SetEngineWarmupTime(value)
        brakes:SetEngineWarmupTime(value)
    end)

    settings:RegisterCallback("speedp", function(value)
        instance.speedPid = PID(value, instance.speedPid.i, instance.speedPid.d)
        log:Info("P:", instance.speedPid.p, " I:", instance.speedPid.i, " D:", instance.speedPid.d)
    end)

    settings:RegisterCallback("speedi", function(value)
        instance.speedPid = PID(instance.speedPid.p, value, instance.speedPid.d)
        log:Info("P:", instance.speedPid.p, " I:", instance.speedPid.i, " D:", instance.speedPid.d)
    end)

    settings:RegisterCallback("speedd", function(value)
        instance.speedPid = PID(instance.speedPid.p, instance.speedPid.i, value)
        log:Info("P:", instance.speedPid.p, " I:", instance.speedPid.i, " D:", instance.speedPid.d)
    end)

    return instance
end

function fsm:SetEngineWarmupTime(t)
    warmupTime = t  * 2 -- Warmup time is to T50, so double it for full engine effect
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

    self.currentWP = next

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

        self:Move(deltaTime)

        self:AdjustForDeviation(chaseData, pos, moveDirection)

        self:ApplyAcceleration(moveDirection, next:GetPrecisionMode())

        visual:DrawNumber(9, chaseData.rabbit)
        visual:DrawNumber(8, chaseData.nearest)
        visual:DrawNumber(0, pos + (self.acceleration or nullVec):normalize() * 8)
    else
        self:ApplyAcceleration(nullVec, false)
    end
end

function fsm:SetTemporaryWaypoint(waypoint)
    self.temporaryWaypoint = waypoint
end

function fsm:CurrentWP()
    return Ternary(self.temporaryWaypoint, self.temporaryWaypoint, self.currentWP)
end

-- Calculates the max allowed speed we may have while still being able to decelerate to the endSpeed
-- Remember to pass in a negative acceleration
local function CalcMaxAllowedSpeed(acceleration, distance, endSpeed)
    -- v^2 = v0^2 + 2a*d
    -- v0^2 = v^2 - 2a*d
    -- v0 = sqrt(v^2 - 2ad)

    local v0 = (endSpeed * endSpeed - 2 * acceleration * distance) ^ 0.5
    return v0
end

---@param deltaTime number The time since last Flush
function fsm:Move(deltaTime)
    local wp = self:CurrentWP()
    local direction = wp:DirectionTo()

    if wp:DistanceTo() == 0 then
        -- Exactly on the target
        self:Thrust()
        return
    end

    local vel = Velocity()

    -- Look ahead at how much there is left at the next tick. If we're decelerating, don't allow values less than 0
    local remainingDistance = max(0, wp:DistanceTo() - (vel:len() * deltaTime + 0.5 * Acceleration():len() * deltaTime * deltaTime))

    local velocityNormal = vel:normalize()

    self.wPointDistance:Set(calc.Round(remainingDistance, 4))

    -- Calculate max speed we may have with available brake force to come to a stop at the target
    -- Might not be enough brakes or engines to counter gravity so don't go below 0
    local gravInfluence = (universe:VerticalReferenceVector() * world.G()):dot(-velocityNormal)
    local brakeAcc = max(0, brakes:Deceleration() + gravInfluence)

    local currentSpeed = vel:len()

    local function ScaleForWarmup()
        local warmupDistance = currentSpeed * self:GetEngineWarmupTime()
        if remainingDistance <= 0 or warmupDistance <= 0 then
            return 1
        end

        return clamp(5 * warmupDistance / remainingDistance, 0, 1)
    end

    -- Gravity is already taken care of for engines
    local engineAcc = max(0, engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-velocityNormal))

    local finalSpeed = wp:FinalSpeed()
    local engineMaxSpeed = CalcMaxAllowedSpeed(-engineAcc * ScaleForWarmup(), remainingDistance, finalSpeed)
    self.wEngineMaxSpeed:Set(calc.Round(calc.Mps2Kph(engineMaxSpeed), 1))

    -- When we're standing still we get no brake speed since brakes gives no force (in atmosphere)
    local brakeMaxSpeed = CalcMaxAllowedSpeed(-brakeAcc * brakeEfficiencyFactor, remainingDistance, finalSpeed)
    self.wBrakeMaxSpeed:Set(calc.Round(calc.Mps2Kph(brakeMaxSpeed), 1))

    local inAtmo = world.IsInAtmo()

    local targetSpeed = construct.getMaxSpeed()

    if inAtmo then
        targetSpeed = min(targetSpeed, construct.getFrictionBurnSpeed())
    end

    if wp:MaxSpeed() > 0 then
        targetSpeed = min(targetSpeed, wp:MaxSpeed())
    end

    -- Speed limit under which atmospheric brakes become less effective (down to 10m/s where they give 0.1 of max)
    local atmoBrakeCutoff = inAtmo and currentSpeed <= 100

    if engineMaxSpeed > 0 then
        if brakeMaxSpeed > 0 and not atmoBrakeCutoff then
            targetSpeed = min(targetSpeed, max(engineMaxSpeed, brakeMaxSpeed))
        else
            targetSpeed = min(targetSpeed, engineMaxSpeed)
        end
    end

    -- Add margin based off distance when going mostly up or down and somewhat close
    if inAtmo and abs(direction:dot(universe:VerticalReferenceVector())) > 0.7 then
        if remainingDistance < 1000 then
            targetSpeed = min(targetSpeed, remainingDistance / 2)
        end
    end

    local pid = self.speedPid
    local diff = targetSpeed - currentSpeed
    pid:inject(diff)

    if direction:dot(velocityNormal) < 0 --[[ and currentSpeed > calc.Kph2Mps(5)]] --[[This speed check causes construct to glide from target pos]] then
        brakes:Set(true, "Direction change")
        --pid:reset()
        --targetSpeed = 0
    elseif diff < 0 then
        -- v = v0 + a*t
        -- a = (v - v0) / t
        local timeLeft = remainingDistance / currentSpeed
        if timeLeft > 1 then
            -- Break over the next second. Use abs(), to provide directionless acceleration value.
            brakes:Set(true, "Reduce speed", abs(diff))
        else
            brakes:Set(true, "Reduce speed")
        end
    end

    self:Thrust(direction * pid:get() * engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(direction))

    self.wTargetSpeed:Set(calc.Round(calc.Mps2Kph(targetSpeed), 2))
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
            ctrl.setEngineCommand(t.engines:Union(), { thrustAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 1)
            ctrl.setEngineCommand(a.engines:Union(), { adjustAcc:unpack() }, { 0, 0, 0 }, 1, 1, a.prio1Tag, a.prio2Tag, a.prio3Tag, 1)
        else
            -- Apply acceleration as a single vector
            local finalAcc = thrustAcc + adjustAcc
            ctrl.setEngineCommand(t.engines:Union(), { finalAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 1)
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