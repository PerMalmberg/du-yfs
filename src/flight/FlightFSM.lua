local r = require("CommonRequire")
local brakes = r.brakes
local vehicle = r.vehicle
local calc = r.calc
local universe = r.universe
local Vec3 = r.Vec3
local nullVec = Vec3()
local ctrl = r.library:GetController()
local visual = r.visual
local sharedPanel = require("du-libs:panel/SharedPanel")()
local engine = r.engine
local EngineGroup = require("du-libs:abstraction/EngineGroup")
local Accumulator = require("du-libs:util/Accumulator")
require("flight/state/Require")
local CurrentPos = vehicle.position.Current
local Velocity = vehicle.velocity.Movement
local Acceleration = vehicle.acceleration.Movement
local abs = math.abs

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
-- Increase this to prevent engines from stopping/starting
local speedMargin = calc.Kph2Mps(1)

local adjustAccLookup = {
    { limit = 0, acc = 0.15, reverse = 0.3 },
    { limit = 0.01, acc = 0.20, reverse = 0.35 },
    { limit = 0.03, acc = 0.30, reverse = 0.40 },
    { limit = 0.05, acc = 0.40, reverse = 0.45 },
    { limit = 0.1, acc = 0, reverse = 0 }
}

local getDeviationAdjustmentAcc = function(accLookup, dir, distance, movingTowardsTarget)
    local selected
    for _, v in ipairs(accLookup) do
        if distance >= v.limit then
            selected = v
        end
    end

    local max
    if selected.acc == 0 then
        max = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(dir)
    else
        max = calc.Ternary(movingTowardsTarget, selected.acc, selected.reverse)
    end

    -- Scale the already small values over the tolerance distance.
    return calc.Scale(distance, 0, toleranceDistance, 0.01, max)
end

local fsm = {}
fsm.__index = fsm

local function new()

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
        deviationAccum = Accumulator:New(10)
    }

    setmetatable(instance, fsm)
    instance:SetState(Idle(instance))
    return instance
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

function fsm:Move(direction, distance, maxSpeed)
    local vel = Velocity()
    local travelDir = vel:normalize()
    local speedDiff = vel:len() - maxSpeed

    self.wPointDistance:Set(calc.Round(distance, 4))

    local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance(distance)

    local needToBrake = brakeDistance >= distance or brakeAccelerationNeeded > 0

    if needToBrake then
        brakes:Set(true)
        self:Thrust(-travelDir * brakeAccelerationNeeded)
    elseif speedDiff > 0 then
        -- Going too fast, brake over the next second
        -- v = v0 + a*t => a = (v - v0) / t => a = speedDiff / t
        -- Since t = 1, acceleration becomes just speedDiff
        brakes:Set(true, speedDiff)
        self:Thrust()
    elseif speedDiff < -speedMargin then
        -- We must not saturate the engines; giving a massive acceleration
        -- causes non-axis aligned movement to push us off the path since engines
        -- then fire with all they got which may not result in the vector we want.
        self:Thrust(direction * engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(direction))
    else
        -- Just counter gravity.
        self:Thrust()
    end

    -- Help come to a stop if we're going in the wrong direction
    if travelDir:dot(direction) < 0 then
        brakes:Set(true)
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

    local calcBrakeDistance = function(speed, acceleration)
        return (speed ^ 2) / (2 * acceleration)
    end

    local calcAcceleration = function(speed, remainingDistance)
        return (speed ^ 2) / (2 * remainingDistance)
    end

    local warmupTime = 1

    local movingTowardsTarget = self.deviationAccum:Add(vel:normalize():dot(dirToTarget) > 0.8) > 0.5

    local maxBrakeAcc = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-toTargetWorld:normalize())
    local brakeDistance = calcBrakeDistance(currSpeed, maxBrakeAcc) + warmupTime * currSpeed
    local speedLimit = calc.Scale(distance, 0, toleranceDistance, adjustmentSpeedMin, adjustmentSpeedMax)

    self.wAdjTowards:Set(movingTowardsTarget)
    self.wAdjDist:Set(calc.Round(distance, 4))
    self.wAdjBrakeDistance:Set(calc.Round(brakeDistance))
    self.wAdjSpeed:Set(calc.Round(currSpeed, 1) .. "(" .. calc.Round(speedLimit, 1) .. ")")

    if distance > 0 then
        -- Are we moving towards target?
        if movingTowardsTarget then
            if brakeDistance > distance or currSpeed > speedLimit then
                self.adjustAcc = -dirToTarget * calcAcceleration(currSpeed, distance)
            elseif distance > self.lastDevDist then
                -- Slipping away, nudge back to path
                self.adjustAcc = dirToTarget * getDeviationAdjustmentAcc(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
            elseif distance < toleranceDistance then
                -- Add brake acc to help stop where we want
                self.adjustAcc = -dirToTarget * calcAcceleration(currSpeed, distance)
            elseif currSpeed < speedLimit then
                -- This check needs to be last so that it doesn't interfere with decelerating towards destination
                self.adjustAcc = dirToTarget * getDeviationAdjustmentAcc(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
            end
        else
            -- Counter current movement, if any
            if currSpeed > 0.1 then
                self.adjustAcc = -vel:normalize() * getDeviationAdjustmentAcc(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
            else
                self.adjustAcc = dirToTarget * getDeviationAdjustmentAcc(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
            end
        end
    else
        self.adjustAcc = nullVec
    end

    self.lastDevDist = distance

    self.wAdjAcc:Set(calc.Round(self.adjustAcc:len(), 2))
end

function fsm:ApplyAcceleration(moveDirection, precision)
    if self.acceleration ~= nil then
        local groups = self:GetEngines(moveDirection, precision)
        local t = groups.thrust
        local a = groups.adjust
        local thrustAcc = (self.acceleration or nullVec) + t.antiG() - Vec3(construct.getWorldAirFrictionAcceleration())
        local adjustAcc = (self.adjustAcc or nullVec) + a.antiG()

        if precision then
            -- Apply acceleration independently
            ctrl.setEngineCommand(t.engines:Intersection(), { thrustAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 0.001)
            ctrl.setEngineCommand(a.engines:Union(), { adjustAcc:unpack() }, { 0, 0, 0 }, 1, 1, a.prio1Tag, a.prio2Tag, a.prio3Tag, 0.001)
        else
            -- Apply acceleration as a single vector, skipping the adjustment acceleration
            local finalAcc = thrustAcc + adjustAcc
            ctrl.setEngineCommand(t.engines:Union(), { finalAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 0.001)
        end
    else
        ctrl.setEngineCommand(thrustTag, { 0, 0, 0 }, { 0, 0, 0 }, 1, 1, "", "", "", 0.001)
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

    -- Ensure state change doesn't cause engines to shutoff
    self:Thrust()
end

function fsm:DisableThrust()
    self.acceleration = nil
    self.adjustAcc = nil
end

function fsm:Thrust(acceleration, adjustAcc)
    self.acceleration = acceleration or nullVec
    self.adjustAcc = adjustAcc or nullVec
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
    local point = nearestPoint + dir * ahead
    local remaining = wpEnd.destination - point

    -- Is the point past the end (remaining points back towards start or we're very close to the destination)?
    if remaining:normalize():dot(dir) < 1 or remaining:len() < 0.01 then
        return { rabbit = wpEnd.destination, nearest = nearestPoint }
    else
        return { rabbit = point, nearest = nearestPoint }
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