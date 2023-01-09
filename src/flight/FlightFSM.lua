local r = require("CommonRequire")
local AxisManager = require("flight/AxisManager")
local log = r.log
local brakes = require("flight/Brakes"):Instance()
local vehicle = r.vehicle
local G = vehicle.world.G
local calc = r.calc
local CalcBrakeAcceleration = calc.CalcBrakeAcceleration
local CalcBrakeDistance = calc.CalcBrakeDistance
local Ternary = calc.Ternary
local universe = r.universe
local Vec3 = r.Vec3
local nullVec = Vec3.New()
local engine = r.engine
local EngineGroup = require("abstraction/EngineGroup")
local Accumulator = require("util/Accumulator")
local Stopwatch = require("system/Stopwatch")
local PID = require("cpml/pid")
local Ray = require("util/Ray")
require("flight/state/Require")
local CurrentPos = vehicle.position.Current
local Velocity = vehicle.velocity.Movement
local TotalMass = vehicle.mass.Total
local Acceleration = vehicle.acceleration.Movement
local GravityDirection = vehicle.world.GravityDirection
local utils = require("cpml/utils")
local pub = require("util/PubSub").Instance()
local clamp = utils.clamp
local abs = math.abs
local min = math.min
local max = math.max
local MAX_INT = math.maxinteger

local atmoBrakeCutoffSpeed = calc.Kph2Mps(360) -- Speed limit under which atmospheric brakes become less effective (down to 10m/s [36km/h] where they give 0.1 of max)
local atmoBrakeEfficiencyFactor = 0.6
local spaceEngineTurnOffTime = 10
local engineTurnOffThreshold = calc.Kph2Mps(100)
local ignoreAtmoBrakeLimitThreshold = calc.Kph2Mps(3)


local longitudinal = "longitudinal"
local vertical = "vertical"
local lateral = "lateral"
local airfoil = "airfoil"
local thrustTag = "thrust"
local Forward = vehicle.orientation.Forward
local Right = vehicle.orientation.Right
local OneKphPh = calc.Kph2Mps(1)
local deadZoneFactor = 0.8 -- Consider the inner edge of the dead zone where we can't brake to start at this percentage of the atmosphere.

---@alias ChaseData { nearest:Vec3, rabbit:Vec3 }

---@class FlightFSM
---@field New fun(settings:Settings):FlightFSM
---@field FsmFlush fun(next:Waypoint, previous:Waypoint)
---@field SetState fun(newState:FlightState)
---@field SetEngineWarmupTime fun(t50:number)
---@field CheckPathAlignment fun(currentPos:Vec3, chaseData:ChaseData)
---@field SetTemporaryWaypoint fun(wp:Waypoint|nil)
---@field Update fun()
---@field WaypointReached fun(isLastWaypoint:boolean, next:Waypoint, previous:Waypoint)
---@field GetSettings fun():Settings

local FlightFSM = {}
FlightFSM.__index = FlightFSM

---Creates a new FligtFSM
---@param settings Settings
---@return FlightFSM
function FlightFSM.New(settings)

    local function antiG()
        return -universe:VerticalReferenceVector() * G()
    end

    local function noAntiG()
        return nullVec
    end

    local normalModeGroup = {
        thrust = {
            engines = EngineGroup(thrustTag, airfoil), prio1Tag = airfoil, prio2Tag = thrustTag, prio3Tag = "",
            antiG = antiG
        },
        adjust = { engines = EngineGroup(), prio1Tag = "", prio2Tag = "", prio3Tag = "", antiG = noAntiG }
    }

    local forwardGroup = {
        thrust = { engines = EngineGroup(longitudinal), prio1Tag = thrustTag, prio2Tag = "", prio3Tag = "",
            antiG = noAntiG },
        adjust = { engines = EngineGroup(airfoil, lateral, vertical), prio1Tag = airfoil, prio2Tag = lateral,
            prio3Tag = vertical, antiG = antiG }
    }

    local rightGroup = {
        thrust = { engines = EngineGroup(lateral), prio1Tag = thrustTag, prio2Tag = "", prio3Tag = "", antiG = noAntiG },
        adjust = { engines = EngineGroup(vertical, longitudinal), prio1Tag = vertical, prio2Tag = longitudinal,
            prio3Tag = "", antiG = antiG }
    }

    local upGroup = {
        thrust = { engines = EngineGroup(vertical), prio1Tag = vertical, prio2Tag = "", prio3Tag = "", antiG = antiG },
        adjust = { engines = EngineGroup(lateral, longitudinal), prio1Tag = vertical, prio2Tag = longitudinal,
            prio3Tag = "", antiG = noAntiG }
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
    local yaw = AxisManager.Instance().Yaw()
    local yawAlignmentThrustLimiter = 1

    ---@type FlightData
    local flightData = {
        targetSpeed = 0,
        targetSpeedReason = "",
        finalSpeed = 0,
        finalSpeedDistance = 0,
        distanceToAtmo = -1,
        dzSpeedInc = 0,
        atmoDistance = 0,
        brakeMaxSpeed = 0,
        waypointDist = 0,
        speedDiff = 0,
        pid = 0,
        fsmState = "No state",
        acceleration = 0,
        controlAcc = 0,
        absSpeed = 0
    }

    local adjustData = {
        towards = false,
        distance = 0,
        brakeDist = 0,
        speed = 0,
        acceleration = 0
    }

    local function warmupDistance()
        -- Note, this doesn't take acceleration into account
        return Velocity():Len() * warmupTime
    end

    local function getAdjustedAcceleration(accLookup, dir, distance, movingTowardsTarget, forThrust)
        local selected
        for _, v in ipairs(accLookup) do
            if distance >= v.limit then selected = v
            else break end
        end

        if selected.acc == 0 then
            if forThrust and distance <= warmupDistance() then
                return accLookup[#accLookup - 1].acc
            else
                return engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(dir, false)
            end
        else
            return calc.Ternary(movingTowardsTarget, selected.acc, selected.reverse)
        end
    end

    local function getEngines(moveDirection, precision)
        if precision then
            if abs(moveDirection:Dot(Forward())) >= 0.707 then
                return forwardGroup
            elseif abs(moveDirection:Dot(Right())) >= 0.707 then
                return rightGroup
            else
                return upGroup
            end
        else
            return normalModeGroup
        end
    end

    --- Calculates the max allowed speed we may have while still being able to decelerate to the endSpeed
    --- Remember to pass in a negative acceleration
    ---@param acceleration number Available desceleration
    ---@param distance number Remaining distance to target
    ---@param endSpeed number Desired speed when reaching target
    ---@return number
    local function calcMaxAllowedSpeed(acceleration, distance, endSpeed)
        -- v^2 = v0^2 + 2a*d
        -- v0^2 = v^2 - 2a*d
        -- v0 = sqrt(v^2 - 2ad)

        local v0 = (endSpeed * endSpeed - 2 * acceleration * distance) ^ 0.5
        return v0
    end

    ---Calculates the nearest point between two waypoints
    ---@param wpStart Waypoint
    ---@param wpEnd Waypoint
    ---@param currentPos Vec3
    ---@param ahead number
    ---@return ChaseData
    local function nearestPointBetweenWaypoints(wpStart, wpEnd, currentPos, ahead)
        local totalDiff = wpEnd.Destination() - wpStart.Destination()
        local dir = totalDiff:Normalize()
        local nearestPoint = calc.NearestPointOnLine(wpStart.Destination(), dir, currentPos)

        ahead = (ahead or 0)
        local startDiff = nearestPoint - wpStart.Destination()
        local distanceFromStart = startDiff:Len()
        local rabbitDistance = min(distanceFromStart + ahead, totalDiff:Len())
        local rabbit = wpStart.Destination() + dir * rabbitDistance

        if startDiff:Normalize():Dot(dir) < 0 then
            return { nearest = wpStart.Destination(), rabbit = rabbit }
        elseif startDiff:Len() >= totalDiff:Len() then
            return { nearest = wpEnd.Destination(), rabbit = rabbit }
        else
            return { nearest = nearestPoint, rabbit = rabbit }
        end
    end

    local currentState ---@type FlightState
    local currentWP ---@type Waypoint
    local temporaryWaypoint ---@type Waypoint|nil
    local lastDevDist = 0
    local deviationAccum = Accumulator:New(10, Accumulator.Truth)

    local delta = Stopwatch.New()

    local speedPid = PID(0.2, 0.005, 0.08, 0.99)

    local s = {}

    ---Selects the waypoint to go to
    ---@return Waypoint
    local function selectWP()
        if temporaryWaypoint == nil then return currentWP else return temporaryWaypoint end
    end

    ---Calculates the width of the dead zone
    ---@param body Body
    local function deadZoneThickness(body)
        local atmo = body.Atmosphere
        local thickness = Ternary(atmo.Present, atmo.Thickness * (1 - deadZoneFactor), 0)
        return thickness
    end

    ---Indicates if the coordinate is within the atmospheric dead zone of the body
    ---@param coordinate Vec3
    ---@param body Body
    ---@return boolean
    local function isWithinDeadZone(coordinate, body)
        if not body.Atmosphere.Present then return false end

        -- If the point is within the atmospheric radius and outside the inner radius, then it is within the dead zone.
        local outerBorder = body.Atmosphere.Radius
        local innerBorder = -deadZoneThickness(body)
        local distanceToCenter = (coordinate - body.Geography.Center):Len()

        return distanceToCenter < outerBorder and distanceToCenter >= innerBorder
    end

    ---Determines if the construct will enter atmo
    ---@param waypoint Waypoint
    ---@param body Body
    ---@return boolean, Vec3, number
    local function willEnterAtmo(waypoint, body)
        local pos = CurrentPos()
        local center = body.Geography.Center
        return calc.LineIntersectSphere(Ray.New(pos, waypoint.DirectionTo()), center, body.Atmosphere.Radius)
    end

    ---Calculates the speed increase while falling through the dead zone
    ---@param body Body
    local function speedIncreaseInDeadZone(body)
        -- V^2 = V0^2 + 2ad, we only want the speed increase so v = sqrt(2ad) for the thickness of the dead zone.
        local d = deadZoneThickness(body)
        return Ternary(body.Atmosphere.Present,
            (2 * body.Physics.Gravity * d) ^ 0.5, 0)
    end

    ---Evaluates the new speed limit and sets that, if lower than the current one
    ---@param currentLimit number Current speed limit
    ---@param newLimit number New speed limit
    ---@param reason string Text to display in the widget
    ---@return number
    local function evaluateNewLimit(currentLimit, newLimit, reason)
        if newLimit >= 0 and newLimit < currentLimit then
            flightData.targetSpeed = newLimit
            flightData.targetSpeedReason = reason
            return newLimit
        end

        return currentLimit
    end

    ---Calculates the start distance for the linear approach
    ---@return number The linear start distance in meters
    local function calcLinearApproachStart()
        if vehicle.world.IsInSpace() then
            return 75
        else
            if TotalMass() > 10000 then
                return 1000
            end

            return 2
        end
    end

    ---Adjust the speed to be linear based on the remaining distance
    ---@param currentTargetSpeed number Current target speed
    ---@param remainingDistance number Remaining distance
    local function linearApproach(currentTargetSpeed, remainingDistance)
        if remainingDistance > calcLinearApproachStart() then
            return currentTargetSpeed
        end

        -- 1000m -> 500kph, 500m -> 250kph etc.
        local distanceBasedSpeedLimit = calc.Kph2Mps(remainingDistance)

        return evaluateNewLimit(currentTargetSpeed, distanceBasedSpeedLimit, "Approaching")
    end

    ---Gets the brake efficiency to use
    ---@param inAtmo boolean
    ---@param speed number
    ---@return number
    local function getBrakeEfficiency(inAtmo, speed)
        if not inAtmo then
            return 1
        end

        if speed <= atmoBrakeCutoffSpeed then
            return 0.1
        else
            return atmoBrakeEfficiencyFactor
        end
    end

    ---Gets the maximum speed we may have and still be able to stop
    ---@param deltaTime number Time since last tick, seconds
    ---@param velocity Vec3 Current velocity
    ---@param direction Vec3 Direction we want to travel
    ---@param waypoint Waypoint Current waypoint
    ---@return number
    local function getSpeedLimit(deltaTime, velocity, direction, waypoint)
        local finalSpeed = waypoint.FinalSpeed()

        local currentSpeed = velocity:Len()
        -- Look ahead at how much there is left at the next tick. If we're decelerating, don't allow values less than 0
        -- This is inaccurate if acceleration isn't in the same direction as our movement vector, but it is gives a safe value.
        local remainingDistance = max(0,
            waypoint.DistanceTo() - (currentSpeed * deltaTime + 0.5 * Acceleration():Len() * deltaTime * deltaTime))

        -- Calculate max speed we may have with available brake force to to reach the final speed.

        -- If we're passing through or into atmosphere, reduce speed before we reach it
        local pos = CurrentPos()
        local firstBody = universe.CurrentGalaxy():BodiesInPath(Ray.New(pos, velocity:Normalize()))[1]
        local inAtmo = false
        flightData.finalSpeed = finalSpeed
        flightData.finalSpeedDistance = remainingDistance

        local targetSpeed = evaluateNewLimit(MAX_INT, construct.getMaxSpeed(), "Construct max")

        if firstBody then
            local willHitAtmo, hitPoint, distanceToAtmo = willEnterAtmo(waypoint, firstBody)
            inAtmo = firstBody:DistanceToAtmo(pos) == 0

            local dzSpeedIncrease = speedIncreaseInDeadZone(firstBody)
            flightData.dzSpeedInc = dzSpeedIncrease

            -- Ensure slowdown before we hit atmo and assume we're going to fall through the dead zone.
            if not inAtmo and willHitAtmo
                and remainingDistance > distanceToAtmo -- Waypoint may be closer than atmo
            then
                finalSpeed = max(0, construct.getFrictionBurnSpeed() - dzSpeedIncrease)
                remainingDistance = distanceToAtmo
                flightData.finalSpeed = finalSpeed
                flightData.finalSpeedDistance = distanceToAtmo
            end

            flightData.distanceToAtmo = distanceToAtmo
        else
            flightData.distanceToAtmo = -1
        end

        if waypoint.MaxSpeed() > 0 then
            targetSpeed = evaluateNewLimit(targetSpeed, waypoint.MaxSpeed(), "Route")
        end

        --- Don't allow us to burn
        if inAtmo then
            targetSpeed = evaluateNewLimit(targetSpeed, construct.getFrictionBurnSpeed(), "Burn speed")
        end

        if firstBody and isWithinDeadZone(pos, firstBody) and direction:Dot(GravityDirection()) > 0.7 then
            remainingDistance = max(remainingDistance, remainingDistance - deadZoneThickness(firstBody))
        end

        if waypoint.Reached() then
            targetSpeed = evaluateNewLimit(targetSpeed, 0, "Hold")
            flightData.brakeMaxSpeed = 0
        else
            -- When in space, engines take a long time to turn off which causes overshoots
            local engineTurnOffDistance = 0
            if not inAtmo and currentSpeed > engineTurnOffThreshold then
                engineTurnOffDistance = currentSpeed * spaceEngineTurnOffTime
            end

            local brakeEfficiency = getBrakeEfficiency(inAtmo, currentSpeed)
            local brakeMaxSpeed = calcMaxAllowedSpeed(
                -brakes:GravityInfluencedAvailableDeceleration() * brakeEfficiency,
                clamp(remainingDistance - engineTurnOffDistance, 0, remainingDistance), finalSpeed)

            -- When standing still in atmo, we get no brake speed as brakes give no force at all.
            if not inAtmo or currentSpeed > ignoreAtmoBrakeLimitThreshold then
                targetSpeed = evaluateNewLimit(targetSpeed, brakeMaxSpeed, "Brakes")
            end

            flightData.brakeMaxSpeed = brakeMaxSpeed

            if inAtmo and abs(direction:Dot(GravityDirection())) > 0.7 then
                -- Moving vertically in atmo
                -- Atmospheric brakes loose effectiveness when we slow down. This means engines must be active
                -- when we come to a stand still. To ensure that engines have enough time to warmup as well as
                -- don't abruptly cut off when going upwards, we enforce a linear slowdown, down to the final speed.
                targetSpeed = linearApproach(targetSpeed, remainingDistance)
            elseif not inAtmo then
                -- In space we want a linear approach just during the last part
                targetSpeed = linearApproach(targetSpeed, remainingDistance)
            end
        end

        flightData.waypointDist = remainingDistance

        return targetSpeed
    end

    ---Adjust for deviation from the desired path
    ---@param chaseData ChaseData
    ---@param currentPos Vec3
    ---@param moveDirection Vec3
    ---@return Vec3
    local function adjustForDeviation(chaseData, currentPos, moveDirection)
        -- Add counter to deviation from optimal path
        local plane = moveDirection:Normalize()
        local vel = Velocity():ProjectOnPlane(plane) / plane:Len2()
        local currSpeed = vel:Len()

        local targetPoint = chaseData.nearest

        local toTargetWorld = targetPoint - currentPos
        local toTarget = calc.ProjectPointOnPlane(plane, currentPos, chaseData.nearest) -
            calc.ProjectPointOnPlane(plane, currentPos, currentPos)
        local dirToTarget = toTarget:Normalize()
        local distance = toTarget:Len()

        local movingTowardsTarget = deviationAccum:Add(vel:Normalize():Dot(dirToTarget) > 0.8) > 0.5

        local maxBrakeAcc = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-toTargetWorld:Normalize(),
            false)
        local brakeDistance = CalcBrakeDistance(currSpeed, maxBrakeAcc) + warmupTime * currSpeed
        local speedLimit = calc.Scale(distance, 0, toleranceDistance, adjustmentSpeedMin, adjustmentSpeedMax)

        adjustData.towards = movingTowardsTarget
        adjustData.distance = distance
        adjustData.brakeDist = brakeDistance
        adjustData.speed = currSpeed

        local adjustmentAcc = nullVec

        if distance > 0 then
            -- Are we moving towards target?
            if movingTowardsTarget then
                if brakeDistance > distance or currSpeed > speedLimit then
                    adjustmentAcc = -dirToTarget * CalcBrakeAcceleration(currSpeed, distance)
                elseif distance > lastDevDist then
                    -- Slipping away, nudge back to path
                    adjustmentAcc = dirToTarget *
                        getAdjustedAcceleration(adjustAccLookup, toTargetWorld:Normalize(), distance, movingTowardsTarget)
                elseif distance < toleranceDistance then
                    -- Add brake acc to help stop where we want
                    adjustmentAcc = -dirToTarget * CalcBrakeAcceleration(currSpeed, distance)
                elseif currSpeed < speedLimit then
                    -- This check needs to be last so that it doesn't interfere with decelerating towards destination
                    adjustmentAcc = dirToTarget *
                        getAdjustedAcceleration(adjustAccLookup, toTargetWorld:Normalize(), distance, movingTowardsTarget)
                end
            else
                -- Counter current movement, if any
                if currSpeed > 0.1 then
                    adjustmentAcc = -vel:Normalize() *
                        getAdjustedAcceleration(adjustAccLookup, toTargetWorld:Normalize(), distance, movingTowardsTarget)
                else
                    adjustmentAcc = dirToTarget *
                        getAdjustedAcceleration(adjustAccLookup, toTargetWorld:Normalize(), distance, movingTowardsTarget)
                end
            end
        end

        lastDevDist = distance
        adjustData.acceleration = adjustmentAcc:Len()

        return adjustmentAcc
    end

    ---Applies the acceleration to the engines
    ---@param acceleration Vec3|nil
    ---@param adjustmentAcc Vec3
    ---@param precision boolean If true, use precision mode
    local function applyAcceleration(acceleration, adjustmentAcc, precision)
        if acceleration == nil then
            unit.setEngineCommand(thrustTag, { 0, 0, 0 }, { 0, 0, 0 }, true, true, "", "", "", 1)
            return
        end

        local groups = getEngines(acceleration, precision)
        local t = groups.thrust
        local adj = groups.adjust

        -- Subtracting the air friction induces jitter on small constructs so we no longer do that on the thrust acceleration.
        local thrustAcc = t.antiG()

        if abs(yaw.OffsetDegrees()) < yawAlignmentThrustLimiter then
            thrustAcc = thrustAcc + acceleration
        end

        local adjustAcc = (adjustmentAcc) + adj.antiG()

        if precision then
            -- Apply acceleration independently
            unit.setEngineCommand(t.engines:Union(), { thrustAcc:Unpack() }, { 0, 0, 0 }, true, true, t.prio1Tag,
                t.prio2Tag, t.prio3Tag, 1)
            unit.setEngineCommand(adj.engines:Union(), { adjustAcc:Unpack() }, { 0, 0, 0 }, true, true,
                adj.prio1Tag, adj.prio2Tag, adj.prio3Tag, 1)
        else
            -- Apply acceleration as a single vector
            local finalAcc = thrustAcc + adjustAcc
            unit.setEngineCommand(t.engines:Union(), { finalAcc:Unpack() }, { 0, 0, 0 }, true, true, t.prio1Tag,
                t.prio2Tag, t.prio3Tag, 1)
        end
    end

    ---@param deltaTime number The time since last Flush
    ---@param waypoint Waypoint The next waypoint
    ---@return Vec3 The acceleration
    local function move(deltaTime, waypoint)
        local direction = waypoint:DirectionTo()

        local velocity = Velocity()
        local currentSpeed = velocity:Len()
        local motionDirection = velocity:Normalize()

        local speedLimit = getSpeedLimit(deltaTime, velocity, direction, waypoint)

        local wrongDir = direction:Dot(motionDirection) < 0
        local brakeCounter = brakes:Feed(Ternary(wrongDir, 0, speedLimit), currentSpeed)

        local diff = speedLimit - currentSpeed
        flightData.speedDiff = diff

        -- Feed the pid with 1/10:th to give it a wider working range.
        speedPid:inject(diff / 10)

        -- Don't let the pid value go outside 0 ... 1 - that would cause the calculated thrust to get
        -- skewed outside its intended values and push us off the path, or make us fall when holding position (if pid gets <0)
        local pidValue = clamp(speedPid:get(), 0, 1)

        flightData.pid = pidValue

        local acceleration

        -- When we're not moving in the direction we should, counter movement with all we got.
        if wrongDir and currentSpeed > calc.Kph2Mps(20) then
            acceleration = -motionDirection *
                engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-motionDirection) + brakeCounter
        else
            -- When we move slow, don't use the brake counter as that induces jitter, especially on small crafts.
            if currentSpeed < ignoreAtmoBrakeLimitThreshold then
                brakeCounter = nullVec
            end

            acceleration = direction * pidValue *
                engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(direction) + brakeCounter
        end

        flightData.controlAcc = acceleration:Len()
        return acceleration
    end

    ---Flush method for the FSM
    ---@param next Waypoint
    ---@param previous Waypoint
    function s.FsmFlush(next, previous)
        local deltaTime = 0
        if delta.IsRunning() then
            deltaTime = delta.Elapsed()
            delta.Restart()
        else
            delta.Start()
        end

        currentWP = next

        if currentState.InhibitsThrust() then
            applyAcceleration(nil, nullVec, false)
        else
            local selectedWP = selectWP()

            local pos = CurrentPos()
            local chaseData = nearestPointBetweenWaypoints(previous, selectedWP, pos, 6)

            currentState.Flush(deltaTime, selectedWP, previous, chaseData)
            local moveDirection = selectedWP.DirectionTo()

            local acceleration = move(deltaTime, selectedWP)
            local adjustmentAcc = adjustForDeviation(chaseData, pos, moveDirection)

            applyAcceleration(acceleration, adjustmentAcc, selectedWP.GetPrecisionMode())

            --visual:DrawNumber(9, chaseData.rabbit)
            --visual:DrawNumber(8, chaseData.nearest)
            --visual:DrawNumber(0, pos + (acceleration or nullVec):Normalize() * 8)
        end
    end

    ---Sets a new state
    ---@param state FlightState
    function s.SetState(state)
        if currentState ~= nil then
            currentState.Leave()
        end

        if state == nil then
            flightData.fsmState = "No state"
            return
        else
            flightData.fsmState = state:Name()
            state.Enter()
        end

        currentState = state
    end

    ---Sets the engine warmup time
    ---@param time number
    function s.SetEngineWarmupTime(time)
        warmupTime = time * 2 -- Warmup time is to T50, so double it for full engine effect
    end

    ---Checks if we're still on the path
    ---@param currentPos Vec3
    ---@param chaseData ChaseData
    ---@return boolean
    function s.CheckPathAlignment(currentPos, chaseData)
        local res = true

        local vel = Velocity()
        local speed = vel:Len()

        local toNearest = chaseData.nearest - currentPos

        if speed > 1 then
            -- TODO: when using a PID to control adjustment, can we maybe use currentWP.Margin() instead? Is the movement thenn accurate enough?
            -- This is not meant to be the same as the waypoint margin which is used to determine when w waypoint has been reached.
            res = toNearest:Len() < toleranceDistance
        end

        return res
    end

    ---Sets a temporary waypoint, or removes the current one
    ---@param waypoint Waypoint|nil
    function s.SetTemporaryWaypoint(waypoint)
        temporaryWaypoint = waypoint
    end

    function s.Update()
        if currentState ~= nil then
            flightData.acceleration = Acceleration():Len()
            flightData.absSpeed = Velocity():Len()
            currentState.Update()
            pub.Publish("FlightData", flightData)
            pub.Publish("AdjustmentData", adjustData)
        end
    end

    function s.WaypointReached(isLastWaypoint, next, previous)
        if currentState ~= nil then
            currentState.WaypointReached(isLastWaypoint, next, previous)
        end
    end

    settings.RegisterCallback("engineWarmup", function(value)
        s.SetEngineWarmupTime(value)
        log:Info("Engine warmup:", value)
    end)

    settings.RegisterCallback("speedp", function(value)
        speedPid = PID(value, speedPid.i, speedPid.d, speedPid.amortization)
        log:Info("P:", speedPid.p, " I:", speedPid.i, " D:", speedPid.d, " A:", speedPid.amortization)
    end)

    settings.RegisterCallback("speedi", function(value)
        speedPid = PID(speedPid.p, value, speedPid.d, speedPid.amortization)
        log:Info("P:", speedPid.p, " I:", speedPid.i, " D:", speedPid.d, " A:", speedPid.amortization)
    end)

    settings.RegisterCallback("speedd", function(value)
        speedPid = PID(speedPid.p, speedPid.i, value, speedPid.amortization)
        log:Info("P:", speedPid.p, " I:", speedPid.i, " D:", speedPid.d, " A:", speedPid.amortization)
    end)

    settings.RegisterCallback("speeda", function(value)
        speedPid = PID(speedPid.p, speedPid.i, speedPid.d, value)
        log:Info("P:", speedPid.p, " I:", speedPid.i, " D:", speedPid.d, " A:", speedPid.amortization)
    end)


    settings.RegisterCallback("yawAlignmentThrustLimiter", function(value)
        yawAlignmentThrustLimiter = value
        log:Info("yawAlignmentThrustLimiter:", value)
    end)

    ---@return Settings
    function s.GetSettings()
        return settings
    end

    s.SetState(Idle.New(s))

    return setmetatable(s, FlightFSM)
end

return FlightFSM
