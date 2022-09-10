local r = require("CommonRequire")
local log = r.log
local brakes = r.brakes
local vehicle = r.vehicle
local world = vehicle.world
local G = vehicle.world.G
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

local FlightFSM = {}
FlightFSM.__index = FlightFSM

function FlightFSM:New(settings)

    local function antiG()
        return -universe:VerticalReferenceVector() * G()
    end

    local function noAntiG()
        return nullVec
    end

    local normalModeGroup = {
        thrust = {
            engines = EngineGroup(thrustTag, airfoil), prio1Tag = airfoil, prio2Tag = thrustTag, prio3Tag = "", antiG = antiG },
            adjust = { engines = EngineGroup(), prio1Tag = "", prio2Tag = "", prio3Tag = "", antiG = noAntiG }
    }

    local forwardGroup = {
        thrust = { engines = EngineGroup(longitudinal), prio1Tag = thrustTag, prio2Tag = "", prio3Tag = "", antiG = noAntiG },
        adjust = { engines = EngineGroup(airfoil, lateral, vertical), prio1Tag = airfoil, prio2Tag = lateral, prio3Tag = vertical, antiG = antiG }
    }

    local rightGroup = {
        thrust = { engines = EngineGroup(lateral), prio1Tag = thrustTag, prio2Tag = "", prio3Tag = "", antiG = noAntiG },
        adjust = { engines = EngineGroup(vertical, longitudinal), prio1Tag = vertical, prio2Tag = longitudinal, prio3Tag = "", antiG = antiG }
    }

    local upGroup = {
        thrust = { engines = EngineGroup(vertical), prio1Tag = vertical, prio2Tag = "", prio3Tag = "", antiG = antiG },
        adjust = { engines = EngineGroup(lateral, longitudinal), prio1Tag = vertical, prio2Tag = longitudinal, prio3Tag = "", antiG = noAntiG }
    }

    local adjustAccLookup = {
        { limit = 0, acc = 0.15, reverse = 0.3 },
        { limit = 0.01, acc = 0.20, reverse = 0.35 },
        { limit = 0.03, acc = 0.30, reverse = 0.40 },
        { limit = 0.05, acc = 0.40, reverse = 0.45 },
        { limit = 0.1, acc = 0, reverse = 0 }
    }

    local toleranceDistance = 2 -- meters. This limit affects the steepness of the acceleration curve used by the deviation adjustment
    local adjustmentSpeedMin = calc.Kph2Mps(0.5)
    local adjustmentSpeedMax = calc.Kph2Mps(50)
    local warmupTime = 1
    local brakeEfficiencyFactor = 0.6

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

    local function getEngines(moveDirection, precision)
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

    -- Calculates the max allowed speed we may have while still being able to decelerate to the endSpeed
    -- Remember to pass in a negative acceleration
    local function calcMaxAllowedSpeed(acceleration, distance, endSpeed)
        -- v^2 = v0^2 + 2a*d
        -- v0^2 = v^2 - 2a*d
        -- v0 = sqrt(v^2 - 2ad)

        local v0 = (endSpeed * endSpeed - 2 * acceleration * distance) ^ 0.5
        return v0
    end

    local function nearestPointBetweenWaypoints(wpStart, wpEnd, currentPos, ahead)
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

    local current

    local p = sharedPanel:Get("Movement")
    local a = sharedPanel:Get("Adjustment")
    local wStateName = p:CreateValue("State", "")
    local wPointDistance = p:CreateValue("Point dist.", "m")
    local wAcceleration = p:CreateValue("Acceleration", "m/s2")
    local wTargetSpeed = p:CreateValue("Target speed", "km/h")
    local wBrakeMaxSpeed = p:CreateValue("Brake Max Speed", "km/h")
    local wEngineMaxSpeed = p:CreateValue("Engine Max Speed", "km/h")
    local wSpeed = a:CreateValue("Abs. speed", "km/h")
    local wAdjTowards = a:CreateValue("Adj. towards")
    local wAdjDist = a:CreateValue("Adj. distance", "m")
    local wAdjAcc = a:CreateValue("Adj. acc", "m/s2")
    local wAdjBrakeDistance = a:CreateValue("Adj. brake dist.", "m")
    local wAdjSpeed = a:CreateValue("Adj. speed (limit)", "m/s")
    local currentWP
    local acceleration
    local adjustmentAcc = nullVec
    local lastDevDist = 0
    local deviationAccum = Accumulator:New(10, Accumulator.Truth)
    local delta = Stopwatch()
    local temporaryWaypoint
    --speedPid = PID(0.01, 0.001, 0.0) -- Large
    local speedPid = PID(0.008, 0, 0.1) -- Small

    local s = {
    }

    function s:SetState(state)
        if current ~= nil then
            current:Leave()
        end

        if state == nil then
            wStateName:Set("No state!")
        else
            wStateName:Set(state:Name())
            state:Enter()
        end

        current = state
    end

    function s:SetEngineWarmupTime(t)
        warmupTime = t  * 2 -- Warmup time is to T50, so double it for full engine effect
    end

    function s:GetEngineWarmupTime()
        return warmupTime
    end

    function s:CheckPathAlignment(currentPos, chaseData)
        local res = true

        local vel = Velocity()
        local speed = vel:len()

        local toNearest = chaseData.nearest - currentPos

        if speed > 1 then
            res = toNearest:len() < toleranceDistance
        end

        return res
    end

    local function getSpeedLimit(deltaTime, velocity, direction, maxSpeed, finalSpeed, distanceToTarget)

        local currentSpeed = velocity:len()
        -- Look ahead at how much there is left at the next tick. If we're decelerating, don't allow values less than 0
        local remainingDistance = max(0, distanceToTarget - (currentSpeed * deltaTime + 0.5 * Acceleration():len() * deltaTime * deltaTime))

        local velocityNormal = velocity:normalize()

        wPointDistance:Set(calc.Round(remainingDistance, 4))

        -- Calculate max speed we may have with available brake force to come to a stop at the target
        -- Might not be enough brakes or engines to counter gravity so don't go below 0
        local brakeAcc = brakes:GravityInfluencedAvailableDeceleration()


        local function ScaleForWarmup()
            local warmupDistance = currentSpeed * s:GetEngineWarmupTime()
            if remainingDistance <= 0 or warmupDistance <= 0 then
                return 1
            end

            return clamp(5 * warmupDistance / remainingDistance, 0, 1)
        end

        -- Gravity is already taken care of for engines
        local engineAcc = max(0, engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-velocityNormal))

        local engineMaxSpeed = calcMaxAllowedSpeed(-engineAcc * ScaleForWarmup(), remainingDistance, finalSpeed)
        wEngineMaxSpeed:Set(calc.Round(calc.Mps2Kph(engineMaxSpeed), 1))

        -- When we're standing still we get no brake speed since brakes gives no force (in atmosphere)
        local brakeMaxSpeed = calcMaxAllowedSpeed(-brakeAcc * brakeEfficiencyFactor, remainingDistance, finalSpeed)
        wBrakeMaxSpeed:Set(calc.Round(calc.Mps2Kph(brakeMaxSpeed), 1))

        local inAtmo = world.IsInAtmo()

        local targetSpeed = construct.getMaxSpeed()

        if inAtmo then
            targetSpeed = min(targetSpeed, construct.getFrictionBurnSpeed())
        end

        if maxSpeed > 0 then
            targetSpeed = min(targetSpeed, maxSpeed)
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

        if direction:dot(velocityNormal) < 0 then
            -- Moving in the wrong direction
            targetSpeed = calc.Kph2Mps(remainingDistance)
        end

        return targetSpeed
    end

    local function adjustForDeviation(chaseData, currentPos, moveDirection)
        -- Add counter to deviation from optimal path
        local plane = moveDirection:normalize()
        local vel = calc.ProjectVectorOnPlane(plane, Velocity())
        local currSpeed = vel:len()

        local targetPoint = chaseData.nearest

        local toTargetWorld = targetPoint - currentPos
        local toTarget = calc.ProjectPointOnPlane(plane, currentPos, chaseData.nearest) - calc.ProjectPointOnPlane(plane, currentPos, currentPos)
        local dirToTarget = toTarget:normalize()
        local distance = toTarget:len()
        
        local movingTowardsTarget = deviationAccum:Add(vel:normalize():dot(dirToTarget) > 0.8) > 0.5

        local maxBrakeAcc = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-toTargetWorld:normalize())
        local brakeDistance = CalcBrakeDistance(currSpeed, maxBrakeAcc) + warmupTime * currSpeed
        local speedLimit = calc.Scale(distance, 0, toleranceDistance, adjustmentSpeedMin, adjustmentSpeedMax)

        wAdjTowards:Set(movingTowardsTarget)
        wAdjDist:Set(calc.Round(distance, 4))
        wAdjBrakeDistance:Set(calc.Round(brakeDistance))
        wAdjSpeed:Set(calc.Round(currSpeed, 1) .. "(" .. calc.Round(speedLimit, 1) .. ")")

        if distance > 0 then
            -- Are we moving towards target?
            if movingTowardsTarget then
                if brakeDistance > distance or currSpeed > speedLimit then
                    adjustmentAcc = -dirToTarget * CalcBrakeAcceleration(currSpeed, distance)
                elseif distance > lastDevDist then
                    -- Slipping away, nudge back to path
                    adjustmentAcc = dirToTarget * getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
                elseif distance < toleranceDistance then
                    -- Add brake acc to help stop where we want
                    adjustmentAcc = -dirToTarget * CalcBrakeAcceleration(currSpeed, distance)
                elseif currSpeed < speedLimit then
                    -- This check needs to be last so that it doesn't interfere with decelerating towards destination
                    adjustmentAcc = dirToTarget * getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
                end
            else
                -- Counter current movement, if any
                if currSpeed > 0.1 then
                    adjustmentAcc = -vel:normalize() * getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
                else
                    adjustmentAcc = dirToTarget * getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
                end
            end
        else
            adjustmentAcc = nullVec
        end

        lastDevDist = distance

        wAdjAcc:Set(calc.Round(adjustmentAcc:len(), 2))
    end

    local function applyAcceleration(moveDirection, precision)
        if acceleration == nil then
            ctrl.setEngineCommand(thrustTag, { 0, 0, 0 }, { 0, 0, 0 }, 1, 1, "", "", "", 0.001)
        else
            local groups = getEngines(moveDirection, precision)
            local t = groups.thrust
            local adj = groups.adjust
            local thrustAcc = acceleration + t.antiG() - Vec3(construct.getWorldAirFrictionAcceleration())
            local adjustAcc = (adjustmentAcc or nullVec) + adj.antiG()

            if precision then
                -- Apply acceleration independently
                ctrl.setEngineCommand(t.engines:Union(), { thrustAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 1)
                ctrl.setEngineCommand(adj.engines:Union(), { adjustAcc:unpack() }, { 0, 0, 0 }, 1, 1, adj.prio1Tag, adj.prio2Tag, adj.prio3Tag, 1)
            else
                -- Apply acceleration as a single vector
                local finalAcc = thrustAcc + adjustAcc
                ctrl.setEngineCommand(t.engines:Union(), { finalAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 1)
            end
        end
    end

    function s:FsmFlush(next, previous)
        local deltaTime = 0
        if delta:IsRunning() then
            deltaTime = delta:Elapsed()
            delta:Restart()
        else
            delta:Start()
        end

        currentWP = next

        local c = current
        if c ~= nil then
            local pos = CurrentPos()
            local chaseData = nearestPointBetweenWaypoints(previous, next, pos, 6)

            -- Assume we're just going to counter gravity.
            acceleration = nullVec
            adjustmentAcc = nullVec

            c:Flush(deltaTime, next, previous, chaseData)
            local moveDirection = next:DirectionTo()

            s:Move(deltaTime)

            adjustForDeviation(chaseData, pos, moveDirection)

            applyAcceleration(moveDirection, next:GetPrecisionMode())

            visual:DrawNumber(9, chaseData.rabbit)
            visual:DrawNumber(8, chaseData.nearest)
            visual:DrawNumber(0, pos + (acceleration or nullVec):normalize() * 8)
        else
            applyAcceleration(nullVec, false)
        end
    end

    function s:SetTemporaryWaypoint(waypoint)
        temporaryWaypoint = waypoint
    end

    function s:CurrentWP()
        return Ternary(temporaryWaypoint, temporaryWaypoint, currentWP)
    end

    function s:Update()
        if current ~= nil then
            wAcceleration:Set(calc.Round(Acceleration():len(), 2))
            wSpeed:Set(calc.Round(calc.Mps2Kph(Velocity():len()), 1))
            current:Update()
        end
    end

    function s:WaypointReached(isLastWaypoint, next, previous)
        if current ~= nil then
            current:WaypointReached(isLastWaypoint, next, previous)
        end
    end

    function s:DisableThrust()
        acceleration = nil
        adjustmentAcc = nil
    end

    function s:NullThrust()
        acceleration = nullVec
        adjustmentAcc = nullVec
    end

    ---@param deltaTime number The time since last Flush
    function s:Move(deltaTime)
        local wp = s:CurrentWP()
        local direction = wp:DirectionTo()
        local remainingDistance = wp:DistanceTo()

        if remainingDistance == 0 then
            -- Exactly on the target
            acceleration = nullVec
            return
        end

        local velocity = Velocity()
        local currentSpeed = velocity:len()

        local speedLimit = getSpeedLimit(deltaTime, velocity, direction, wp:MaxSpeed(), wp:FinalSpeed(), remainingDistance)

        local brakeCounter = brakes:Feed(speedLimit, currentSpeed)

        speedPid:inject(speedLimit - currentSpeed)

        -- Don't let the pid value go outside -1 ... 1 - that would cause the calculated thrust to get
        -- skewed outside its intended values and push us off the path.
        local pidValue = clamp(speedPid:get(), -1, 1)

        acceleration = direction * pidValue * engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(direction) + brakeCounter

        wTargetSpeed:Set(calc.Round(calc.Mps2Kph(speedLimit), 2))
    end


    settings:RegisterCallback("engineWarmup", function(value)
        s:SetEngineWarmupTime(value)
    end)

    settings:RegisterCallback("speedp", function(value)
        speedPid = PID(value, speedPid.i, speedPid.d)
        log:Info("P:", speedPid.p, " I:", speedPid.i, " D:", speedPid.d)
    end)

    settings:RegisterCallback("speedi", function(value)
        speedPid = PID(speedPid.p, value, speedPid.d)
        log:Info("P:", speedPid.p, " I:", speedPid.i, " D:", speedPid.d)
    end)

    settings:RegisterCallback("speedd", function(value)
        speedPid = PID(speedPid.p, speedPid.i, value)
        log:Info("P:", speedPid.p, " I:", speedPid.i, " D:", speedPid.d)
    end)

    
    s:SetState(Idle(s))

    return setmetatable(s, FlightFSM)
end

return FlightFSM