local log                         = require("debug/Log").Instance()
local Vec3                        = require("math/Vec3")
local vehicle                     = require("abstraction/Vehicle").New()
local universe                    = require("universe/Universe").Instance()
local calc                        = require("util/Calc")
local yfsConstants                = require("YFSConstants")
local LightConstructMassThreshold = yfsConstants.flight.lightConstructMassThreshold
local DefaultMargin               = yfsConstants.flight.defaultMargin
local AxisManager                 = require("flight/AxisManager")
local AdjustmentTracker           = require("flight/AdjustmentTracker")
local Waypoint                    = require("flight/Waypoint")
local brakes                      = require("flight/Brakes"):Instance()
local G                           = vehicle.world.G
local AirFrictionAcc              = vehicle.world.AirFrictionAcceleration
local Sign                        = calc.Sign
local AngleToDot                  = calc.AngleToDot
local nullVec                     = Vec3.zero
local engine                      = require("abstraction/Engine").Instance()
local Stopwatch                   = require("system/Stopwatch")
local PID                         = require("cpml/pid")
local Ray                         = require("util/Ray")
local pub                         = require("util/PubSub").Instance()
local input                       = require("input/Input").Instance()
local SetEngineCommand            = unit.setEngineCommand
local SetEngineThrust             = unit.setEngineThrust
local IsFrozen                    = player.isFrozen
local InAtmo                      = vehicle.world.IsInAtmo

require("flight/state/Require")
local CurrentPos                    = vehicle.position.Current
local Velocity                      = vehicle.velocity.Movement
local Acceleration                  = vehicle.acceleration.Movement
local GravityDirection              = vehicle.world.GravityDirection
local AtmoDensity                   = vehicle.world.AtmoDensity
local TotalMass                     = vehicle.mass.Total
local Clamp                         = calc.Clamp
local abs                           = math.abs
local min                           = math.min
local max                           = math.max
local MAX_INT                       = math.maxinteger

local ignoreAtmoBrakeLimitThreshold = calc.Kph2Mps(3)
local brakeDegradeSpeed             = calc.Kph2Mps(360)

local Up                            = vehicle.orientation.Up
local Forward                       = vehicle.orientation.Forward
local Right                         = vehicle.orientation.Right
local deadZoneFactor                = 0.8 -- Consider the inner edge of the dead zone where we can't brake to start at this percentage of the atmosphere.
local adjustAngleThreshold          = calc.AngleToDot(45)

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
---@field DisablesAllThrust fun():boolean
---@field PreventNextWp fun():boolean
---@field SelectWP fun():Waypoint
---@field ToggleBoster fun()
---@field SetBooster fun(activate:boolean)

local FlightFSM                     = {}
FlightFSM.__index                   = FlightFSM

---Creates a new FligtFSM
---@param settings Settings
---@param routeController RouteController
--- @param geo GeoFence
---@return FlightFSM
function FlightFSM.New(settings, routeController, geo)
    local minimumPathCheckOffset = settings.Number("minimumPathCheckOffset")
    settings.Callback("minimumPathCheckOffset", function(number)
        minimumPathCheckOffset = number
    end)

    local globalMaxSpeed = calc.Kph2Mps(settings.Number("globalMaxSpeed"))
    settings.Callback("globalMaxSpeed", function(gMax)
        globalMaxSpeed = calc.Kph2Mps(gMax)
    end)

    settings.Callback("pathAlignmentAngleLimit", Waypoint.SetAlignmentAngleLimit)
    settings.Callback("pathAlignmentDistanceLimit", Waypoint.SetAlignmentDistanceLimit)

    local warmupTime                = 1
    local lastReadMass              = TotalMass()
    local yaw                       = AxisManager.Instance().Yaw()
    local yawAlignmentThrustLimiter = 1
    local boosterActive             = false
    local boosterStateChanged       = false
    local isFrozen                  = false

    local longAdjData               = AdjustmentTracker.New(lastReadMass < LightConstructMassThreshold)
    local latAdjData                = AdjustmentTracker.New(lastReadMass < LightConstructMassThreshold)
    local vertAdjData               = AdjustmentTracker.New(lastReadMass < LightConstructMassThreshold)

    ---@type FlightData
    local flightData                = {
        targetSpeed = 0,
        targetSpeedReason = "",
        finalSpeed = 0,
        finalSpeedDistance = 0,
        distanceToAtmo = -1,
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

    local adjustData                = {
        long = 0,
        lat = 0,
        ver = 0
    }

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

    local delta = Stopwatch.New()

    local pidValues = yfsConstants.flight.speedPid
    local speedPid = PID(pidValues.p, pidValues.i, pidValues.d, pidValues.a)

    local s = {}

    ---@param active boolean
    function s.SetBooster(active)
        if active ~= boosterActive then
            boosterActive = active
            boosterStateChanged = true
            log.Info("Boosters ", boosterActive and "activated" or "deactivated")
        end
    end

    ---Selects the waypoint to go to
    ---@return Waypoint
    function s.SelectWP()
        return temporaryWaypoint and temporaryWaypoint or currentWP
    end

    ---Calculates the width of the dead zone
    ---@param body Body
    local function deadZoneThickness(body)
        local atmo = body.Atmosphere
        local thickness = atmo.Present and (atmo.Thickness * (1 - deadZoneFactor)) or 0
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
    ---If already in atmo it returns false
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
            if lastReadMass > LightConstructMassThreshold then
                startDist = 20
                stopDist = 0.3
            else
                startDist = 0.5
                stopDist = 0
            end
        else
            startDist = 20
            stopDist = 0.0 -- This used to be 0.5, but that caused problems holding position.
        end

        if remainingDistance > startDist
            or remainingDistance <= stopDist then -- To not make it painfully slow in reaching the final position we let it go when it is this close from the target
            return currentTargetSpeed
        end

        return evaluateNewLimit(currentTargetSpeed, linearSpeed(remainingDistance), "Approaching")
    end


    ---@param waypoint Waypoint
    ---@return boolean
    local function outsideAdjustmentMargin(waypoint)
        local margin = waypoint.Margin()
        return longAdjData.LastDistance() > margin
            or latAdjData.LastDistance() > margin
            or vertAdjData.LastDistance() > margin
    end

    local function burnSpeed()
        return construct.getFrictionBurnSpeed() * 0.98
    end

    ---Gets the maximum speed we may have and still be able to stop
    ---@param deltaTime number Time since last tick, seconds
    ---@param velocity Vec3 Current velocity
    ---@param waypoint Waypoint Current waypoint
    ---@param previousWaypoint Waypoint Previous waypoint
    ---@return number
    local function getSpeedLimit(deltaTime, velocity, waypoint, previousWaypoint)
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

        local willHitAtmo = false
        local distanceToAtmo = -1

        local targetSpeed = evaluateNewLimit(MAX_INT, construct.getMaxSpeed(), "Construct max")

        if firstBody then
            willHitAtmo, _, distanceToAtmo = willEnterAtmo(waypoint, firstBody)
            inAtmo = firstBody:IsInAtmo(pos)
            willLeaveAtmo = inAtmo and not firstBody:IsInAtmo(waypoint.Destination())
            flightData.distanceToAtmo = distanceToAtmo
        end

        if waypoint.MaxSpeed() > 0 then
            targetSpeed = evaluateNewLimit(targetSpeed, waypoint.MaxSpeed(), "Route")
        end

        --- Don't allow us to burn
        if atmoDensity > 0 then
            targetSpeed = evaluateNewLimit(targetSpeed, burnSpeed(), "Burn speed")
        end

        local inDeadZone = firstBody and isWithinDeadZone(pos, firstBody)
        local fallingInDeadZone = inDeadZone and waypoint.DirectionTo():Dot(GravityDirection()) > 0.7
        if fallingInDeadZone then
            remainingDistance = max(remainingDistance, remainingDistance - deadZoneThickness(firstBody))
        end

        local availableBrakeDeceleration = brakes.EffectiveBrakeDeceleration()

        -- Ensure slowdown before we hit atmo and assume we're going to fall through the dead zone.
        local atmosphericEntrySpeed = burnSpeed()
        if willHitAtmo then
            flightData.finalSpeed = atmosphericEntrySpeed
            flightData.finalSpeedDistance = distanceToAtmo

            -- Are actually intending to enter atmo?
            if distanceToAtmo <= waypoint.DistanceTo() then
                local entrySpeed = calcMaxAllowedSpeed(availableBrakeDeceleration,
                    distanceToAtmo, atmosphericEntrySpeed)
                targetSpeed = evaluateNewLimit(targetSpeed, entrySpeed, "Atmo entry")
            end
        elseif fallingInDeadZone then
            targetSpeed = evaluateNewLimit(targetSpeed, atmosphericEntrySpeed, "Dead Zone")
        end

        -- Ensure that we have a speed at which we can come to a stop with 10% of the brake force when we hit 360km/h, which is the speed at which brakes start to degrade down to 10% at 36km/h.
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
                        "Final atmo")
                end
            end
        end

        if inAtmo and abs(availableBrakeDeceleration) <= G() then
            -- Brakes have become so inefficient at the current altitude or speed they are useless, use linear speed
            -- This state can be seen when entering atmo for example.
            targetSpeed = evaluateNewLimit(targetSpeed, linearSpeed(remainingDistance), "Brake/ineff")
            -- Does final speed override?
            local finalSpeed = waypoint.FinalSpeed()
            if targetSpeed < finalSpeed and finalSpeed > 0 then
                targetSpeed = evaluateNewLimit(finalSpeed + 1, finalSpeed, "Final spd")
            end
        elseif inAtmo and willLeaveAtmo then
            -- No need to further reduce
        else
            local brakeMaxSpeed = calcMaxAllowedSpeed(availableBrakeDeceleration, remainingDistance,
                waypoint.FinalSpeed())
            targetSpeed = evaluateNewLimit(targetSpeed, brakeMaxSpeed, "Brake")
            flightData.brakeMaxSpeed = brakeMaxSpeed
        end

        if not inAtmo then
            -- Braking in space
            -- Space engines take a while to turn off so if we'd reach the end point within that time, adjust speed
            -- so we brake earlier, but only if we're coming to a stop (finalSpeed == 0)
            if currentSpeed > 0 and waypoint.FinalSpeed() == 0 then
                local timeToStarget = remainingDistance / currentSpeed
                -- These 10 seconds are totally arbitrary, but seems safe enough.
                if timeToStarget <= 10 then
                    targetSpeed = evaluateNewLimit(targetSpeed, targetSpeed * 0.5, "Brake/red")
                end
            end
        end

        flightData.waypointDist = remainingDistance

        if waypoint.FinalSpeed() == 0 then
            targetSpeed = linearApproach(targetSpeed, remainingDistance)
            local pathAlignment = (waypoint.Destination() - previousWaypoint.Destination()):Normalize():Dot(universe
                .VerticalReferenceVector())
            local approachingVertically = abs(pathAlignment) > AngleToDot(5) -- Both up up and down

            -- When approching the final parking position vertically, move extra slow so that there is enough time to adjust sideways.
            if waypoint.IsLastInRoute()
                and outsideAdjustmentMargin(waypoint)
                and approachingVertically -- within this angle
                and remainingDistance < 400 then
                targetSpeed = evaluateNewLimit(targetSpeed, targetSpeed * 0.5, "Adj. apr.")
            end
        end


        if globalMaxSpeed > 0 then
            targetSpeed = evaluateNewLimit(targetSpeed, globalMaxSpeed, "Global max")
        end

        if geo.Limited(waypoint.DirectionTo()) then
            targetSpeed = evaluateNewLimit(targetSpeed, 0, "Geofence")
        end

        return targetSpeed
    end

    ---@param axis Vec3
    ---@param currentPos Vec3
    ---@param nextWaypoint Waypoint
    ---@param previousWaypoint Waypoint
    ---@param t number Time interval in seconds
    ---@return Vec3 direction
    ---@return number length
    local function getAdjustmentDataInFuture(axis, currentPos, nextWaypoint, previousWaypoint, t)
        -- Don't make adjustments in the travel direction.
        if abs(axis:Dot(nextWaypoint:DirectionTo())) < adjustAngleThreshold then
            local posInFuture = currentPos + Velocity() * t + 0.5 * Acceleration() * t * t
            local targetFuture = calc.NearestOnLineBetweenPoints(previousWaypoint.Destination(),
                nextWaypoint.Destination(),
                posInFuture)
            local toTargetFuture = (targetFuture - posInFuture):ProjectOn(axis)
            return toTargetFuture:NormalizeLen()
        else
            return Vec3.zero, 0
        end
    end

    ---@param axis Vec3
    ---@param currentPos Vec3
    ---@param data AdjustmentTracker
    ---@param nextWaypoint Waypoint
    ---@param previousWaypoint Waypoint
    ---@return Vec3 acceleration
    ---@return number distance
    ---@return integer Sign Positive if we need to move in the axis direction
    local function calcAdjustAcceleration(axis, data, currentPos, nextWaypoint, previousWaypoint)
        local directionNow, distanceNow = getAdjustmentDataInFuture(axis, currentPos, nextWaypoint, previousWaypoint, 0)
        local directionFuture, distanceFuture = getAdjustmentDataInFuture(axis, currentPos, nextWaypoint,
            previousWaypoint, 4)

        local acc = Vec3.zero

        if directionNow:Dot(directionFuture) < 0 then
            -- Will have passed the path, break if we'll be outside the margin;
            -- we check this so that we don't prevent ourselves from moving sideways etc.
            if distanceFuture > DefaultMargin
                and lastReadMass > LightConstructMassThreshold -- Don't do the braking on light constructs, it causes jitter.
            then
                acc = directionFuture * calc.CalcBrakeAcceleration(Velocity():Dot(axis), distanceNow)
            end
        else
            local mul = Clamp(data.Feed(distanceNow), 0, 1)
            acc = directionNow * mul *
                engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(directionNow)
        end

        return acc, distanceNow, Sign(directionNow:Dot(axis))
    end

    ---Adjust for deviation from the desired path
    ---@param currentPos Vec3
    ---@param nextWaypoint Waypoint
    ---@param previousWaypoint Waypoint
    ---@return Vec3
    local function adjustForDeviation(currentPos, nextWaypoint, previousWaypoint)
        local vertAcc, vertDist, vertDistSign = calcAdjustAcceleration(Up(), vertAdjData, currentPos, nextWaypoint,
            previousWaypoint)
        local latAcc, latDist, latDistSign = calcAdjustAcceleration(Right(), latAdjData, currentPos, nextWaypoint,
            previousWaypoint)
        local longAcc, longDist, longDistSign = calcAdjustAcceleration(Forward(), longAdjData, currentPos, nextWaypoint,
            previousWaypoint)

        adjustData.lat = latDist * latDistSign
        adjustData.long = longDist * longDistSign
        adjustData.ver = vertDist * vertDistSign

        return vertAcc + latAcc + longAcc
    end

    ---Applies the acceleration to the engines
    ---@param acceleration Vec3|nil
    ---@param adjustmentAcc Vec3
    local function applyAcceleration(acceleration, adjustmentAcc)
        if acceleration == nil then
            SetEngineCommand("thrust", { 0, 0, 0 }, { 0, 0, 0 }, true, true, "", "", "", 1)
            return
        end

        local acc = adjustmentAcc - universe:VerticalReferenceVector() * G() - AirFrictionAcc()

        if abs(yaw.OffsetDegrees()) < yawAlignmentThrustLimiter then
            acc = acc + acceleration * input.Throttle() -- throttle also affects brake acceleration using engines
        end

        -- Make sure that engine tags only include the absolute minimum number of engines as it
        -- is the first command to and engine that takes effect, not the last one. For example,
        -- lateral engines must be adressed with 'lateran AND analog' or a lateral rocket engine
        -- also gets the command.

        -- Vertical AND analog
        SetEngineCommand("vertical analog", { acc:ProjectOn(Up()):Unpack() }, { 0, 0, 0 }, true, true, "airfoil",
            "ground", "analog", 0.1)

        -- longitudinal AND analog
        SetEngineCommand("longitudinal analog", { acc:ProjectOn(Forward()):Unpack() }, { 0, 0, 0 }, true, true, "",
            "", "", 0.1)

        -- When in manual mode we want to counter lateral drift by the same amount of force as air friction.
        -- Note the two-multiplier to counter it already being subtracted above
        local driftComp = AirFrictionAcc():ProjectOn(Right()) * ((isFrozen and InAtmo()) and 2 or 0)

        -- Lateral AND analog
        SetEngineCommand("lateral analog", { (acc:ProjectOn(Right()) + driftComp):Unpack() }, { 0, 0, 0 }, true,
            true, "", "", "", 0.1)

        if boosterStateChanged then
            boosterStateChanged = false
            SetEngineThrust("rocket_engine", boosterActive and 1 or 0)
        end
    end

    ---@param deltaTime number The time since last Flush
    ---@param waypoint Waypoint The next waypoint
    ---@param previousWaypoint Waypoint The next waypoint
    ---@return Vec3 The acceleration
    local function move(deltaTime, waypoint, previousWaypoint)
        local direction = waypoint.DirectionTo()

        local velocity = Velocity()
        local motionDirection, currentSpeed = velocity:NormalizeLen()

        local speedLimit = getSpeedLimit(deltaTime, velocity, waypoint, previousWaypoint)

        local alignmentToDir = direction:Dot(motionDirection)
        local wrongDir = alignmentToDir < 0 or abs(alignmentToDir) < adjustAngleThreshold

        local brakeCounter = brakes.Feed(wrongDir and 0 or speedLimit, currentSpeed)

        local diff = speedLimit - currentSpeed
        flightData.speedDiff = diff

        -- Only feed speed pid when not going fast enough to avoid accelerating when speed is too high
        if diff >= 0 then
            -- Feed the pid with 1/100:th to give it a wider working range.
            speedPid:inject(diff / 100)
        else
            speedPid:reset()
        end

        -- Don't let the pid value go outside 0 ... 1 - that would cause the calculated thrust to get
        -- skewed outside its intended values and push us off the path, or make us fall when holding position (if pid gets <0)
        local pidValue = Clamp(speedPid:get(), 0, 1)

        flightData.pid = pidValue

        -- When we move slow, don't use the brake counter as that induces jitter, especially on small crafts and not when in space
        if currentSpeed < ignoreAtmoBrakeLimitThreshold and AtmoDensity() > 0.09 then
            brakeCounter = nullVec
        end

        local acceleration
        if waypoint.DistanceTo() <= DefaultMargin then
            -- At this point we let the adjustment code control
            acceleration = Vec3.zero
        else
            acceleration = direction * pidValue *
                engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(direction)
        end

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

        if currentState.DisablesAllThrust() then
            applyAcceleration(nil, nullVec)
            brakes.Feed(0, Velocity():Len())
        else
            local selectedWP = s.SelectWP()

            local pos = CurrentPos()
            local nearest = calc.NearestOnLineBetweenPoints(previous.Destination(), selectedWP.Destination(), pos)

            currentState.Flush(deltaTime, selectedWP, previous, nearest)

            if brakes.Active() then
                s.SetBooster(false)
            end

            local acceleration = move(deltaTime, selectedWP, previous)
            local adjustmentAcc = adjustForDeviation(pos, selectedWP, previous)

            applyAcceleration(acceleration, adjustmentAcc)
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

        return toNearest <= max(minimumPathCheckOffset, allowedOffset)
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
        lastReadMass = TotalMass()
        isFrozen = IsFrozen()
    end

    function s.AtWaypoint(isLastWaypoint, next, previous)
        if currentState ~= nil then
            currentState.AtWaypoint(isLastWaypoint, next, previous)
        end
    end

    settings.Callback("engineWarmup", function(value)
        s.SetEngineWarmupTime(value)
    end)

    settings.Callback("speedp", function(value)
        speedPid = PID(value, speedPid.i, speedPid.d, speedPid.amortization)
    end)

    settings.Callback("speedi", function(value)
        speedPid = PID(speedPid.p, value, speedPid.d, speedPid.amortization)
    end)

    settings.Callback("speedd", function(value)
        speedPid = PID(speedPid.p, speedPid.i, value, speedPid.amortization)
    end)

    settings.Callback("speeda", function(value)
        speedPid = PID(speedPid.p, speedPid.i, speedPid.d, value)
    end)

    settings.Callback("yawAlignmentThrustLimiter", function(value)
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

    function s.DisablesAllThrust()
        return currentState and currentState.DisablesAllThrust() or false
    end

    function s.PreventNextWp()
        return currentState and currentState.PreventNextWp() or false
    end

    s.SetState(Idle.New(s))

    return setmetatable(s, FlightFSM)
end

return FlightFSM
