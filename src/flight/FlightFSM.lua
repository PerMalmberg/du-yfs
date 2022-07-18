local brakes = require("flight/Brakes")()
local vehicle = require("du-libs:abstraction/Vehicle")()
local calc = require("du-libs:util/Calc")
local ctrl = require("du-libs:abstraction/Library")():GetController()
local visual = require("du-libs:debug/Visual")()
local nullVec = require("cpml/vec3")()
local sharedPanel = require("du-libs:panel/SharedPanel")()
local universe = require("du-libs:universe/Universe")()
local engine = require("du-libs:abstraction/Engine")()
local EngineGroup = require("du-libs:abstraction/EngineGroup")
local Vec3 = require("cpml/vec3")
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

local toleranceDistance = 3 -- meters
local adjustmentSpeedMin = calc.Kph2Mps(0.5)
local adjustmentSpeedMax = calc.Kph2Mps(50)

local fsm = {}
fsm.__index = fsm

local function new()

    local p = sharedPanel:Get("FlightFSM")
    local a = sharedPanel:Get("Deviation")

    local instance = {
        current = nil,
        wStateName = p:CreateValue("State", ""),
        wAcceleration = p:CreateValue("Acceleration", "m/s2"),
        wSpeed = p:CreateValue("Speed", "m/s"),
        wAdjTowards = a:CreateValue("Towards"),
        wAdjDist = a:CreateValue("Distance", "m"),
        wAdjAcc = a:CreateValue("Acceleration", "m/s2"),
        wAdjBrakeDistance = a:CreateValue("Brake dist.", "m"),
        wAdjSpeed = a:CreateValue("Speed (limit)", "m/s"),
        nearestPoint = nil,
        acceleration = nil,
        adjustAcc = nullVec,
        lastDevDist = 0,
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
        local moveDirection = next:DirectionTo()
        self:AdjustForDeviation(next.margin, chaseData, pos, moveDirection)

        self:ApplyAcceleration(moveDirection, next:GetPrecisionMode())

        visual:DrawNumber(9, chaseData.rabbit)
        visual:DrawNumber(8, chaseData.nearest)
        visual:DrawNumber(0, pos + (self.acceleration or nullVec):normalize() * 8)
    else
        self:ApplyAcceleration(nullVec, false)
    end
end

-- Get the shortest distance between a point and a plane. The output is signed so it holds information
-- as to which side of the plane normal the point is.
local signedDistancePlanePoint = function(planeNormal, planePoint, point)
    return planeNormal:dot(point - planePoint);
end

local projectPointOnPlane = function(planeNormal, planePoint, point)
    -- First calculate the distance from the point to the plane:
    local distance = signedDistancePlanePoint(planeNormal, planePoint, point)

    -- Reverse the sign of the distance
    distance = distance * -1;

    -- Get a translation vector
    local translationVector = planeNormal * distance

    -- Translate the point to form a projection
    return point + translationVector
end

-- Projects a vector onto a plane. The output is not normalized.
local projectVectorOnPlane = function(planeNormal, vector)
    return vector - vector:dot(planeNormal) * planeNormal
end

function fsm:AdjustForDeviation(margin, chaseData, currentPos, moveDirection)
    -- https://github.com/GregLukosek/3DMath/blob/master/Math3D.cs

    -- Add counter to deviation from optimal path
    local plane = moveDirection:normalize()
    local vel = projectVectorOnPlane(plane, Velocity())
    local currSpeed = vel:len()
    local toTargetWorld = chaseData.nearest - currentPos
    local toTarget = projectPointOnPlane(plane, currentPos, chaseData.nearest) - projectPointOnPlane(plane, currentPos, currentPos)
    local dirToTarget = toTarget:normalize()
    local distance = toTarget:len()

    local calcBrakeDistance = function(speed, acceleration)
        return (speed ^ 2) / (2 * acceleration)
    end

    local calcAcceleration = function(speed, distance)
        return (speed ^ 2) / (2 * distance)
    end

    local getAcc = function(dir)
        local maxAcc = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(dir)
        return dirToTarget * calc.Scale(toTarget:len(), 0, toleranceDistance, 0, maxAcc)
    end

    local warmupTime = 1

    local movingTowardsTarget = vel:normalize():dot(dirToTarget) > 0.707
    local maxBrakeAcc = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-toTargetWorld:normalize())
    local brakeDistance = calcBrakeDistance(currSpeed, maxBrakeAcc) + warmupTime * currSpeed
    local speedLimit = calc.Scale(toTarget:len(), 0, toleranceDistance, adjustmentSpeedMin, adjustmentSpeedMax)

    self.wAdjTowards:Set(movingTowardsTarget)
    self.wAdjDist:Set(calc.Round(distance, 4))
    self.wAdjBrakeDistance:Set(calc.Round(brakeDistance))
    self.wAdjSpeed:Set(calc.Round(currSpeed, 1) .. "(" .. calc.Round(speedLimit, 1) .. ")")

    if distance > 0 and distance >= margin then
        -- Are we moving towards target?
        if movingTowardsTarget then
            if brakeDistance > distance or currSpeed > speedLimit then
                self.adjustAcc = -dirToTarget * calcAcceleration(currSpeed, distance)
            elseif distance > self.lastDevDist or currSpeed < speedLimit then
                -- Slipping away
                self.adjustAcc = getAcc(toTargetWorld:normalize())
            end
        else
            self.adjustAcc = getAcc(toTargetWorld:normalize())
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