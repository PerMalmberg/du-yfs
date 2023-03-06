local r = require("CommonRequire")
local yfsConstants = require("YFSConstants")
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
local CurrentPos                    = vehicle.position.Current
local Velocity                      = vehicle.velocity.Movement
local Acceleration                  = vehicle.acceleration.Movement
local GravityDirection              = vehicle.world.GravityDirection
local AtmoDensity                   = vehicle.world.AtmoDensity
local TotalMass                     = vehicle.mass.Total
local utils                         = require("cpml/utils")
local pub                           = require("util/PubSub").Instance()
local clamp                         = utils.clamp
local abs                           = math.abs
local min                           = math.min
local max                           = math.max
local MAX_INT                       = math.maxinteger

local ignoreAtmoBrakeLimitThreshold = calc.Kph2Mps(3)

local longitudinal                  = "longitudinal"
local vertical                      = "vertical"
local lateral                       = "lateral"
local airfoil                       = "airfoil"
local thrustTag                     = "thrust"
local Forward                       = vehicle.orientation.Forward
local Right                         = vehicle.orientation.Right
local deadZoneFactor                = 0.8 -- Consider the inner edge of the dead zone where we can't brake to start at this percentage of the atmosphere.

---@class FlightFSM
---@field New fun(settings:Settings):FlightFSM
---@field FsmFlush fun(next:Waypoint, previous:Waypoint)
---@field SetState fun(newState:FlightState)
---@field SetEngineWarmupTime fun(t50:number)
---@field CheckPathAlignment fun(currentPos:Vec3, nearestPointOnPath:Vec3, previousWaypoint:Waypoint, nextWaypoint:Waypoint)
---@field SetTemporaryWaypoint fun(wp:Waypoint|nil)
---@field Update fun()
---@field AtWaypoint fun(isLastWaypoint:boolean, next:Waypoint, previous:Waypoint)
---@field GetSettings fun():Settings
---@field GetRouteController fun():RouteController
---@field SetFlightCore fun(fc:FlightCore)
---@field GetFlightCore fun():FlightCore

local FlightFSM                     = {}
FlightFSM.__index                   = FlightFSM

---Creates a new FligtFSM
---@param settings Settings
---@param routeController RouteController
---@return FlightFSM
function FlightFSM.New(settings, routeController)
    local function antiG()
        return -universe:VerticalReferenceVector() * G()
    end

    local function noAntiG()
        return nullVec
    end

    local normalModeGroup = {
        thrust = {
            engines = EngineGroup(thrustTag, airfoil),
            prio1Tag = airfoil,
            prio2Tag = thrustTag,
            prio3Tag = "",
            antiG = antiG
        },
        adjust = { engines = EngineGroup(), prio1Tag = "", prio2Tag = "", prio3Tag = "", antiG = noAntiG }
    }

    local forwardGroup = {
        thrust = {
            engines = EngineGroup(longitudinal),
            prio1Tag = thrustTag,
            prio2Tag = "",
            prio3Tag = "",
            antiG = noAntiG
        },
        adjust = {
            engines = EngineGroup(airfoil, lateral, vertical),
            prio1Tag = airfoil,
            prio2Tag = lateral,
            prio3Tag = vertical,
            antiG = antiG
        }
    }

    local rightGroup = {
        thrust = { engines = EngineGroup(lateral), prio1Tag = thrustTag, prio2Tag = "", prio3Tag = "", antiG = noAntiG },
        adjust = {
            engines = EngineGroup(vertical, longitudinal),
            prio1Tag = vertical,
            prio2Tag = longitudinal,
            prio3Tag = "",
            antiG = antiG
        }
    }

    local upGroup = {
        thrust = { engines = EngineGroup(vertical), prio1Tag = vertical, prio2Tag = "", prio3Tag = "", antiG = antiG },
        adjust = {
            engines = EngineGroup(lateral, longitudinal),
            prio1Tag = vertical,
            prio2Tag = longitudinal,
            prio3Tag = "",
            antiG = noAntiG
        }
    }

    local adjustAccLookup = {
        { limit = 0,    acc = 0.001, reverse = 0.001 },
        { limit = 0.05, acc = 0.20,  reverse = 0.4 },
        { limit = 0.1,  acc = 0.30,  reverse = 0.7 },
        { limit = 0.15, acc = 0.40,  reverse = 0.8 },
        { limit = 0.2,  acc = 0.40,  reverse = 1 },
        { limit = 1,    acc = 1,     reverse = 2 },
        { limit = 1.25, acc = 0,     reverse = 0 }
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

    local function getAdjustedAcceleration(accLookup, distance, movingTowardsTarget)
        local selected
        for _, v in ipairs(accLookup) do
            if distance >= v.limit then
                selected = v
            else
                break
            end
        end

        if selected.acc == 0 then
            selected = accLookup[#accLookup - 1]
        end

        return calc.Ternary(movingTowardsTarget, selected.acc, selected.reverse)
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

    local currentState ---@type FlightState
    local currentWP ---@type Waypoint
    local temporaryWaypoint ---@type Waypoint|nil
    local lastDevDist = 0
    local deviationAccum = Accumulator:New(10, Accumulator.Truth)

    local delta = Stopwatch.New()

    local pidValues = yfsConstants.flight.speedPid
    local speedPid = PID(pidValues.p, pidValues.i, pidValues.d, pidValues.a)

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
        local innerBorder = outerBorder - deadZoneThickness(body)
        local distanceToCenter = (coordinate - body.Geography.Center):Len()

        return distanceToCenter < outerBorder and distanceToCenter >= innerBorder
    end

    ---Determines if the construct will enter atmo if continuing on the current path
    ---@param waypoint Waypoint
    ---@param body Body
    ---@return boolean, Vec3, number
    local function willEnterAtmo(waypoint, body)
        local pos = CurrentPos()
        local center = body.Geography.Center
        local intersects, point, dist = calc.LineIntersectSphere(Ray.New(pos, waypoint.DirectionTo()), center,
            body.Atmosphere.Radius)
        intersects = intersects and not body:IsInAtmo(pos)
        return intersects, point, dist
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

    ---@param remainingDistance number Remaining distance
    local function linearSpeed(remainingDistance)
        -- 1000m -> 1000km/h, 500m -> 500km/h etc.
        local speed = calc.Kph2Mps(remainingDistance)

        if remainingDistance < 2 then
            speed = speed * 2
        end

        return speed
    end

    ---Adjust the speed to be linear based on the remaining distance
    ---@param currentTargetSpeed number Current target speed
    ---@param remainingDistance number Remaining distance
    ---@return number Speed
    local function linearApproach(currentTargetSpeed, remainingDistance)
        local startDist
        local stopDist

        if vehicle.world.IsInAtmo() then
            if TotalMass() > 50000 then
                startDist = 20
                stopDist = 0.3
            else
                startDist = 0.5
                stopDist = 0
            end
        else
            startDist = 20
            stopDist = 0.5
        end

        if remainingDistance > startDist
            or remainingDistance <= stopDist then -- To not make it painfully slow in reaching the final position we let it go when it is this close from the target
            return currentTargetSpeed
        end

        return evaluateNewLimit(currentTargetSpeed, linearSpeed(remainingDistance), "Approaching")
    end

    ---Gets the maximum speed we may have and still be able to stop
    ---@param deltaTime number Time since last tick, seconds
    ---@param velocity Vec3 Current velocity
    ---@param direction Vec3 Direction we want to travel
    ---@param waypoint Waypoint Current waypoint
    ---@return number
    local function getSpeedLimit(deltaTime, velocity, direction, waypoint)
        local currentSpeed = velocity:Len()
        -- Look ahead at how much there is left at the next tick. If we're decelerating, don't allow values less than 0
        -- This is inaccurate if acceleration isn't in the same direction as our movement vector, but it is gives a safe value.
        local remainingDistance = max(0,
            waypoint.DistanceTo() - (currentSpeed * deltaTime + 0.5 * Acceleration():Len() * deltaTime * deltaTime))

        -- Calculate max speed we may have with available brake force to to reach the final speed.

        local pos = CurrentPos()
        local firstBody = universe.CurrentGalaxy():BodiesInPath(Ray.New(pos, velocity:Normalize()))[1]
        local inAtmo = false
        local willLeaveAtmo = false
        local atmoDensity = AtmoDensity()

        flightData.finalSpeed = waypoint.FinalSpeed()
        flightData.finalSpeedDistance = remainingDistance

        local atmosphericEntrySpeed = 0
        local willHitAtmo = false
        local distanceToAtmo = -1
        local dzSpeedIncrease = 0

        local targetSpeed = evaluateNewLimit(MAX_INT, construct.getMaxSpeed(), "Construct max")

        if firstBody then
            willHitAtmo, _, distanceToAtmo = willEnterAtmo(waypoint, firstBody)
            inAtmo = firstBody:IsInAtmo(pos)
            willLeaveAtmo = inAtmo and not firstBody:IsInAtmo(waypoint.Destination())
            dzSpeedIncrease = speedIncreaseInDeadZone(firstBody)
            flightData.dzSpeedInc = dzSpeedIncrease
            flightData.distanceToAtmo = distanceToAtmo
        end

        if waypoint.MaxSpeed() > 0 then
            targetSpeed = evaluateNewLimit(targetSpeed, waypoint.MaxSpeed(), "Route")
        end

        --- Don't allow us to burn
        if atmoDensity > 0 then
            targetSpeed = evaluateNewLimit(targetSpeed, construct.getFrictionBurnSpeed() * 0.99, "Burn speed")
        end

        if firstBody and isWithinDeadZone(pos, firstBody) and direction:Dot(GravityDirection()) > 0.7 then
            remainingDistance = max(remainingDistance, remainingDistance - deadZoneThickness(firstBody))
        end

        local brakeEfficiency = brakes.BrakeEfficiency(inAtmo, currentSpeed)

        if atmoDensity > 0 then
            brakeEfficiency = brakeEfficiency * atmoDensity
        end

        local availableBrakeDeceleration = -brakes.GravityInfluencedAvailableDeceleration() * brakeEfficiency

        if inAtmo and currentSpeed < ignoreAtmoBrakeLimitThreshold then
            -- When standing still in atmo, assume brakes gives current g of brake acceleration (brake API gives a 0 as response in this case)
            local maxSeen = brakes.MaxSeenGravityInfluencedAvailableAtmoDeceleration()
            availableBrakeDeceleration = -max(maxSeen, G())
        end

        -- Ensure slowdown before we hit atmo and assume we're going to fall through the dead zone.
        if willHitAtmo and remainingDistance > distanceToAtmo then -- Waypoint may be closer than atmo
            atmosphericEntrySpeed = max(dzSpeedIncrease, construct.getFrictionBurnSpeed() - dzSpeedIncrease)
            flightData.finalSpeed = atmosphericEntrySpeed
            flightData.finalSpeedDistance = distanceToAtmo

            -- When we're moving towards the atmosphere, but not actually intending to enter it, such as when changing direction
            -- of the route (up->down) and doing the 'return to path' procedure, brake calculations must not use the atmo distance as the input.
            if distanceToAtmo <= waypoint.DistanceTo() then
                local entrySpeed = calcMaxAllowedSpeed(availableBrakeDeceleration,
                    distanceToAtmo, atmosphericEntrySpeed)
                targetSpeed = evaluateNewLimit(targetSpeed, entrySpeed, "Atmo entry")
            end
        end

        -- Ensure that we have a speed at which we can come to a stop with 10% of the brake force when we hit 360km/h, which is the speed at which brakes start to degrade down to 10% at 36km/h.
        local brakeDegradeSpeed = calc.Kph2Mps(360)
        if inAtmo and not willLeaveAtmo and waypoint.FinalSpeed() <= brakeDegradeSpeed then
            local tenPercent = brakes.MaxSeenGravityInfluencedAvailableAtmoDeceleration() * 0.1
            if tenPercent > 0 then
                local endSpeed = waypoint.FinalSpeed()

                local finalApproachDistance = calc.CalcBrakeDistance(brakeDegradeSpeed, tenPercent)
                local toBrakePoint = remainingDistance - finalApproachDistance

                if toBrakePoint > 0 then
                    -- Not yet reached the break point
                    targetSpeed = evaluateNewLimit(targetSpeed,
                        calcMaxAllowedSpeed(-tenPercent, toBrakePoint, brakeDegradeSpeed),
                        "Appr. fin.")
                    flightData.finalSpeed = brakeDegradeSpeed
                    flightData.finalSpeedDistance = toBrakePoint
                else
                    -- Within
                    targetSpeed = evaluateNewLimit(targetSpeed,
                        calcMaxAllowedSpeed(-tenPercent, remainingDistance, endSpeed),
                        "Final")
                end
            end
        end

        if inAtmo and abs(availableBrakeDeceleration) <= G() then
            -- Brakes have become so inefficient at the current altitude or speed they are useless, use linear speed
            -- This state can be seen when entering atmo for example.
            targetSpeed = evaluateNewLimit(targetSpeed, linearSpeed(remainingDistance), "Brake/ineff")
        elseif inAtmo and willLeaveAtmo then
            -- No need to further reduce
        else
            local brakeMaxSpeed = calcMaxAllowedSpeed(availableBrakeDeceleration, remainingDistance,
                waypoint.FinalSpeed())
            targetSpeed = evaluateNewLimit(targetSpeed, brakeMaxSpeed, "Brake")
            flightData.brakeMaxSpeed = brakeMaxSpeed
        end


        flightData.waypointDist = remainingDistance

        if waypoint.FinalSpeed() == 0 then
            targetSpeed = linearApproach(targetSpeed, remainingDistance)
        end

        return targetSpeed
    end

    ---Adjust for deviation from the desired path
    ---@param targetPoint Vec3
    ---@param currentPos Vec3
    ---@param moveDirection Vec3
    ---@return Vec3
    local function adjustForDeviation(targetPoint, currentPos, moveDirection)
        -- Add counter to deviation from optimal path
        local plane = moveDirection:Normalize()
        local vel = Velocity():ProjectOnPlane(plane) / plane:Len2()
        local currSpeed = vel:Len()

        local toTargetWorld = targetPoint - currentPos
        local toTarget = calc.ProjectPointOnPlane(plane, currentPos, targetPoint) - currentPos
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
                        getAdjustedAcceleration(adjustAccLookup, distance, movingTowardsTarget)
                elseif distance < toleranceDistance then
                    -- Add brake acc to help stop where we want
                    adjustmentAcc = -dirToTarget * CalcBrakeAcceleration(currSpeed, distance)
                elseif currSpeed < speedLimit then
                    -- This check needs to be last so that it doesn't interfere with decelerating towards destination
                    adjustmentAcc = dirToTarget *
                        getAdjustedAcceleration(adjustAccLookup, distance, movingTowardsTarget)
                end
            else
                -- Counter current movement, if any
                if currSpeed > 0.1 then
                    adjustmentAcc = -vel:Normalize() *
                        getAdjustedAcceleration(adjustAccLookup, distance, movingTowardsTarget)
                else
                    adjustmentAcc = dirToTarget *
                        getAdjustedAcceleration(adjustAccLookup, distance, movingTowardsTarget)
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
        local direction = waypoint.DirectionTo()

        local velocity = Velocity()
        local currentSpeed = velocity:Len()
        local motionDirection = velocity:Normalize()

        local speedLimit = getSpeedLimit(deltaTime, velocity, direction, waypoint)

        local wrongDir = direction:Dot(motionDirection) < 0.7
        local brakeCounter = brakes.Feed(Ternary(wrongDir, 0, speedLimit), currentSpeed)

        local diff = speedLimit - currentSpeed
        flightData.speedDiff = diff

        -- Only feed speed pid when not going fast enough to avoid accelerating when speed is too high
        if diff >= 0 then
            -- Feed the pid with 1/10:th to give it a wider working range.
            speedPid:inject(diff / 10)
        else
            speedPid:reset()
        end

        -- Don't let the pid value go outside 0 ... 1 - that would cause the calculated thrust to get
        -- skewed outside its intended values and push us off the path, or make us fall when holding position (if pid gets <0)
        local pidValue = clamp(speedPid:get(), 0, 1)

        flightData.pid = pidValue

        -- When we move slow, don't use the brake counter as that induces jitter, especially on small crafts and not when in space
        if currentSpeed < ignoreAtmoBrakeLimitThreshold and AtmoDensity() > 0.09 then
            brakeCounter = nullVec
        end

        local acceleration = direction * pidValue *
            engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(direction)

        flightData.controlAcc = acceleration:Len()
        return acceleration + brakeCounter
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
            brakes.Feed(0, Velocity():Len())
        else
            local selectedWP = selectWP()

            local pos = CurrentPos()
            local nearest = calc.NearestOnLineBetweenPoints(previous.Destination(), selectedWP.Destination(), pos)

            currentState.Flush(deltaTime, selectedWP, previous, nearest)
            local moveDirection = selectedWP.DirectionTo()

            local acceleration = move(deltaTime, selectedWP)
            local adjustmentAcc = adjustForDeviation(nearest, pos, moveDirection)

            applyAcceleration(acceleration, adjustmentAcc, selectedWP.GetPrecisionMode())
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
    ---@param nearestPointOnPath Vec3
    ---@param previousWaypoint Waypoint
    ---@param nextWaypoint Waypoint
    ---@return boolean
    function s.CheckPathAlignment(currentPos, nearestPointOnPath, previousWaypoint, nextWaypoint)
        --[[ As waypoints can have large margins, we need to ensure that we allow for offsets as large as the margins, at each end.
            The outer edges are a straight line between the edges of the start and end point spheres so allowed offset can be calculated linearly.
        ]]
        local startPos = previousWaypoint.Destination()
        local startMargin = previousWaypoint.Margin()
        local endPos = nextWaypoint.Destination()
        local endMargin = nextWaypoint.Margin()

        local dist = (endPos - startPos):Len()
        local diff = endMargin - startMargin
        local koeff = 0
        if dist ~= 0 then
            koeff = diff / dist
        end

        local travelDist = min(dist, (startPos - CurrentPos()):Len())
        local allowedOffset = startMargin + koeff * travelDist
        local toNearest = (nearestPointOnPath - currentPos):Len()

        return toNearest <= max(0.5, allowedOffset)
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

    function s.AtWaypoint(isLastWaypoint, next, previous)
        if currentState ~= nil then
            currentState.AtWaypoint(isLastWaypoint, next, previous)
        end
    end

    settings.RegisterCallback("engineWarmup", function(value)
        s.SetEngineWarmupTime(value)
        log:Info("Engine warmup:", value)
    end)

    settings.RegisterCallback("speedp", function(value)
        speedPid = PID(value, speedPid.i, speedPid.d, speedPid.amortization)
    end)

    settings.RegisterCallback("speedi", function(value)
        speedPid = PID(speedPid.p, value, speedPid.d, speedPid.amortization)
    end)

    settings.RegisterCallback("speedd", function(value)
        speedPid = PID(speedPid.p, speedPid.i, value, speedPid.amortization)
    end)

    settings.RegisterCallback("speeda", function(value)
        speedPid = PID(speedPid.p, speedPid.i, speedPid.d, value)
    end)

    settings.RegisterCallback("yawAlignmentThrustLimiter", function(value)
        yawAlignmentThrustLimiter = value
    end)

    ---@return Settings
    function s.GetSettings()
        return settings
    end

    ---@return RouteController
    function s.GetRouteController()
        return routeController
    end

    local fc ---@type FlightCore

    function s.SetFlightCore(core)
        fc = core
    end

    function s.GetFlightCore()
        return fc
    end

    s.SetState(Idle.New(s))

    return setmetatable(s, FlightFSM)
end

return FlightFSM
