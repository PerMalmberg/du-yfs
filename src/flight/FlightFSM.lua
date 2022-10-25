local r = require("CommonRequire")
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
local nullVec = Vec3()
local visual = r.visual
local sharedPanel = require("panel/SharedPanel")()
local engine = r.engine
local EngineGroup = require("abstraction/EngineGroup")
local Accumulator = require("util/Accumulator")
local Stopwatch = require("system/Stopwatch")
local PID = require("cpml/pid")
local Ray = require("util/Ray")
require("flight/state/Require")
local CurrentPos = vehicle.position.Current
local Velocity = vehicle.velocity.Movement
local Acceleration = vehicle.acceleration.Movement
local GravityDirection = vehicle.world.GravityDirection
local utils = require("cpml/utils")
local clamp = utils.clamp
local abs = math.abs
local min = math.min
local max = math.max
local MAX_INT = math.maxinteger

local brakeCutoffSpeed = 100 -- Speed limit under which atmospheric brakes become less effective (down to 10m/s where they give 0.1 of max)
local linearThreshold = brakeCutoffSpeed * 2
local longitudinal = "longitudinal"
local vertical = "vertical"
local lateral = "lateral"
local airfoil = "airfoil"
local thrustTag = "thrust"
local Forward = vehicle.orientation.Forward
local Right = vehicle.orientation.Right
local OneKphPh = calc.Kph2Mps(1)
local deadZoneFactor = 0.8 -- Consider the inner edge of the dead zone where we can't brake to start at this percentage of the atmosphere.

---@alias ChaseData { nearest:vec3, rabbit:vec3 }

---@class FlightFSM
---@field New fun(settings:Settings):FlightFSM
---@field FsmFlush fun(next:Waypoint, previous:Waypoint)
---@field SetState fun(newState:FlightState)
---@field SetEngineWarmupTime fun(t50:number)
---@field CheckPathAlignment fun(currentPos:vec3, chaseData:ChaseData)
---@field SetTemporaryWaypoint fun(wp:Waypoint)
---@field Update fun()
---@field WaypointReached fun(isLastWaypoint:boolean, next:Waypoint, previous:Waypoint)

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

    local atmoBrakeEfficiencyFactor = 0.6

    local function warmupDistance()
        -- Note, this doesn't take acceleration into account
        return Velocity():len() * warmupTime
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
    ---@param currentPos vec3
    ---@param ahead number
    ---@return ChaseData
    local function nearestPointBetweenWaypoints(wpStart, wpEnd, currentPos, ahead)
        local totalDiff = wpEnd.Destination() - wpStart.Destination()
        local dir = totalDiff:normalize()
        local nearestPoint = calc.NearestPointOnLine(wpStart.Destination(), dir, currentPos)

        ahead = (ahead or 0)
        local startDiff = nearestPoint - wpStart.Destination()
        local distanceFromStart = startDiff:len()
        local rabbitDistance = min(distanceFromStart + ahead, totalDiff:len())
        local rabbit = wpStart.Destination() + dir * rabbitDistance

        if startDiff:normalize():dot(dir) < 0 then
            return { nearest = wpStart.Destination(), rabbit = rabbit }
        elseif startDiff:len() >= totalDiff:len() then
            return { nearest = wpEnd.Destination(), rabbit = rabbit }
        else
            return { nearest = nearestPoint, rabbit = rabbit }
        end
    end

    local currentState ---@type FlightState

    local p = sharedPanel:Get("Movement")
    local a = sharedPanel:Get("Adjustment")
    local wStateName = p:CreateValue("State", "")
    local wPointDistance = p:CreateValue("Point dist.", "m")
    local wAcceleration = p:CreateValue("Acceleration", "m/s2")
    local wTargetSpeed = p:CreateValue("Target speed", "km/h")
    local wFinalSpeed = p:CreateValue("Final speed")
    local wDZSpeedInc = p:CreateValue("DZ spd. inc.", "km/h")
    local wSpeedDiff = p:CreateValue("Speed diff", "km/h")
    local wBrakeMaxSpeed = p:CreateValue("Brake Max Speed", "km/h")
    local wPid = p:CreateValue("Pid")
    local wDistToAtmo = p:CreateValue("Atmo dist.", "m")
    local wSpeed = a:CreateValue("Abs. speed", "km/h")
    local wAdjTowards = a:CreateValue("Adj. towards")
    local wAdjDist = a:CreateValue("Adj. distance", "m")
    local wAdjAcc = a:CreateValue("Adj. acc", "m/s2")
    local wAdjBrakeDistance = a:CreateValue("Adj. brake dist.", "m")
    local wAdjSpeed = a:CreateValue("Adj. speed (limit)", "m/s")
    local currentWP
    local temporaryWaypoint
    local lastDevDist = 0
    local deviationAccum = Accumulator:New(10, Accumulator.Truth)

    local delta = Stopwatch.New()

    local speedPid = PID(0.1, 0, 0.01)

    local s = {}


    ---Selects the waypoint to go to
    ---@return Waypoint
    local function selectWP()
        return Ternary(temporaryWaypoint, temporaryWaypoint, currentWP)
    end

    ---Calculates the width of the dead zone
    ---@param body Body
    local function deadZoneThickness(body)
        local atmo = body.Atmosphere
        local thickness = Ternary(atmo.Present, atmo.Thickness * (1 - deadZoneFactor), 0)
        return thickness
    end

    ---Indicates if the coordinate is within the atmospheric dead zone of the body
    ---@param coordinate vec3
    ---@param body Body
    local function isWithinDeadZone(coordinate, body)
        if not body.Atmosphere.Present then return false end

        -- If the point is within the atmospheric radius and outside the inner radius, then it is within the dead zone.
        local outerBorder = body.Atmosphere.Radius
        local innerBorder = -deadZoneThickness(body)
        local distanceToCenter = (coordinate - body.Geography.Center):len()

        return distanceToCenter < outerBorder and distanceToCenter >= innerBorder
    end

    ---Determines if the construct will enter atmo
    ---@param waypoint Waypoint
    ---@param body Body
    ---@return boolean, vec3, number
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
            wTargetSpeed:Set(string.format("%.1f (%s)", calc.Mps2Kph(newLimit), reason))
            return newLimit
        end

        return currentLimit
    end

    ---Gets the maximum speed we may have and still be able to stop
    ---@param deltaTime number Time since last tick, seconds
    ---@param velocity vec3 Current velocity
    ---@param direction vec3 Direction we want to travel
    ---@param waypoint Waypoint Current waypoint
    ---@return number
    local function getSpeedLimit(deltaTime, velocity, direction, waypoint)
        local finalSpeed = waypoint.FinalSpeed()

        local currentSpeed = velocity:len()
        -- Look ahead at how much there is left at the next tick. If we're decelerating, don't allow values less than 0
        -- This is inaccurate if acceleration isn't in the same direction as our movement vector, but it is gives a safe value.
        local remainingDistance = max(0,
            waypoint.DistanceTo() - (currentSpeed * deltaTime + 0.5 * Acceleration():len() * deltaTime * deltaTime))

        -- Calculate max speed we may have with available brake force to to reach the final speed.

        -- If we're passing through or into atmosphere, reduce speed before we reach it
        local pos = CurrentPos()
        local firstBody = universe.CurrentGalaxy():BodiesInPath(Ray.New(pos, velocity:normalize()))[1]
        local inAtmo = false
        wFinalSpeed:Set(string.format("%.1f km/h in %.1f m", calc.Mps2Kph(finalSpeed), remainingDistance))

        local targetSpeed = evaluateNewLimit(MAX_INT, construct.getMaxSpeed(), "Construct max")

        if firstBody then
            local willHitAtmo, hitPoint, distanceToAtmo = willEnterAtmo(waypoint, firstBody)
            inAtmo = firstBody:DistanceToAtmo(pos) == 0

            local dzSpeedIncrease = speedIncreaseInDeadZone(firstBody)
            wDZSpeedInc:Set(calc.Mps2Kph(dzSpeedIncrease))

            if not inAtmo and willHitAtmo then
                -- Override to ensure slowdown before we hit atmo and assume we're going to fall through the dead zone.
                finalSpeed = max(0, construct.getFrictionBurnSpeed() - dzSpeedIncrease)
                remainingDistance = distanceToAtmo
                wFinalSpeed:Set(string.format("%.1f km/h in %.1f m", calc.Mps2Kph(finalSpeed), distanceToAtmo))
            end

            wDistToAtmo:Set(calc.Round(distanceToAtmo, 1))
        else
            wDistToAtmo:Set("-")
        end

        local brakeEfficiency = Ternary(inAtmo, atmoBrakeEfficiencyFactor, 1)

        if waypoint.MaxSpeed() > 0 then
            targetSpeed = evaluateNewLimit(targetSpeed, waypoint.MaxSpeed(), "Route")
        end

        --- Don't allow us to burn
        if inAtmo then
            targetSpeed = evaluateNewLimit(targetSpeed, construct.getFrictionBurnSpeed(), "Burn speed")
        end

        if firstBody and isWithinDeadZone(pos, firstBody) and direction:dot(GravityDirection()) > 0.7 then
            remainingDistance = max(remainingDistance, remainingDistance - deadZoneThickness(firstBody))
        end

        if waypoint.Reached() then
            targetSpeed = evaluateNewLimit(targetSpeed, 0, "Hold")
            wBrakeMaxSpeed:Set(0)
        else
            local brakeMaxSpeed = calcMaxAllowedSpeed(
                -brakes:GravityInfluencedAvailableDeceleration() * brakeEfficiency,
                remainingDistance, finalSpeed)

            -- When standing still, we get no brake speed as brakes give no force at all.
            if brakeMaxSpeed > 0 then
                targetSpeed = evaluateNewLimit(targetSpeed, brakeMaxSpeed, "Brakes")
            end

            wBrakeMaxSpeed:Set(calc.Round(calc.Mps2Kph(brakeMaxSpeed), 1))

            if inAtmo and abs(direction:dot(GravityDirection())) > 0.7 and
                brakeMaxSpeed <= linearThreshold then
                -- Atmospheric brakes loose effectiveness when we slow down. This means engines must be active
                -- when we come to a stand still. To ensure that engines have enough time to warmup as well as
                -- don't abruptly cut off when going upwards, we enforce a linear slowdown, down to the final speed.

                -- 1000m -> 500kph, 500m -> 250kph etc.
                local distanceBasedSpeedLimit = calc.Kph2Mps(remainingDistance * 0.8)
                distanceBasedSpeedLimit = max(distanceBasedSpeedLimit, finalSpeed)
                if distanceBasedSpeedLimit < OneKphPh then
                    distanceBasedSpeedLimit = OneKphPh
                end

                targetSpeed = evaluateNewLimit(targetSpeed, distanceBasedSpeedLimit, "Approaching")
            end
        end

        wPointDistance:Set(calc.Round(remainingDistance, 2))

        return targetSpeed
    end

    ---Adjust for deviation from the desired path
    ---@param chaseData ChaseData
    ---@param currentPos vec3
    ---@param moveDirection vec3
    ---@return vec3
    local function adjustForDeviation(chaseData, currentPos, moveDirection)
        -- Add counter to deviation from optimal path
        local plane = moveDirection:normalize()
        local vel = calc.ProjectVectorOnPlane(plane, Velocity())
        local currSpeed = vel:len()

        local targetPoint = chaseData.nearest

        local toTargetWorld = targetPoint - currentPos
        local toTarget = calc.ProjectPointOnPlane(plane, currentPos, chaseData.nearest) -
            calc.ProjectPointOnPlane(plane, currentPos, currentPos)
        local dirToTarget = toTarget:normalize()
        local distance = toTarget:len()

        local movingTowardsTarget = deviationAccum:Add(vel:normalize():dot(dirToTarget) > 0.8) > 0.5

        local maxBrakeAcc = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-toTargetWorld:normalize(),
            false)
        local brakeDistance = CalcBrakeDistance(currSpeed, maxBrakeAcc) + warmupTime * currSpeed
        local speedLimit = calc.Scale(distance, 0, toleranceDistance, adjustmentSpeedMin, adjustmentSpeedMax)

        wAdjTowards:Set(movingTowardsTarget)
        wAdjDist:Set(calc.Round(distance, 4))
        wAdjBrakeDistance:Set(calc.Round(brakeDistance))
        wAdjSpeed:Set(calc.Round(currSpeed, 1) .. "(" .. calc.Round(speedLimit, 1) .. ")")

        local adjustmentAcc = nullVec ---@type vec3

        if distance > 0 then
            -- Are we moving towards target?
            if movingTowardsTarget then
                if brakeDistance > distance or currSpeed > speedLimit then
                    adjustmentAcc = -dirToTarget * CalcBrakeAcceleration(currSpeed, distance)
                elseif distance > lastDevDist then
                    -- Slipping away, nudge back to path
                    adjustmentAcc = dirToTarget *
                        getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
                elseif distance < toleranceDistance then
                    -- Add brake acc to help stop where we want
                    adjustmentAcc = -dirToTarget * CalcBrakeAcceleration(currSpeed, distance)
                elseif currSpeed < speedLimit then
                    -- This check needs to be last so that it doesn't interfere with decelerating towards destination
                    adjustmentAcc = dirToTarget *
                        getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
                end
            else
                -- Counter current movement, if any
                if currSpeed > 0.1 then
                    adjustmentAcc = -vel:normalize() *
                        getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
                else
                    adjustmentAcc = dirToTarget *
                        getAdjustedAcceleration(adjustAccLookup, toTargetWorld:normalize(), distance, movingTowardsTarget)
                end
            end
        end

        lastDevDist = distance

        wAdjAcc:Set(calc.Round(adjustmentAcc:len(), 2))
        return adjustmentAcc
    end

    ---Applies the acceleration to the engines
    ---@param acceleration vec3|nil
    ---@param adjustmentAcc vec3
    ---@param precision boolean If true, use precision mode
    local function applyAcceleration(acceleration, adjustmentAcc, precision)
        if acceleration == nil then
            unit.setEngineCommand(thrustTag, { 0, 0, 0 }, { 0, 0, 0 }, true, true, "", "", "", 1)
            return
        end

        local groups = getEngines(acceleration, precision)
        local t = groups.thrust
        local adj = groups.adjust
        local thrustAcc = acceleration + t.antiG() - Vec3(construct.getWorldAirFrictionAcceleration())
        local adjustAcc = (adjustmentAcc) + adj.antiG()

        if precision then
            -- Apply acceleration independently
            unit.setEngineCommand(t.engines:Union(), { thrustAcc:unpack() }, { 0, 0, 0 }, true, true, t.prio1Tag,
                t.prio2Tag, t.prio3Tag, 1)
            unit.setEngineCommand(adj.engines:Union(), { adjustAcc:unpack() }, { 0, 0, 0 }, true, true,
                adj.prio1Tag, adj.prio2Tag, adj.prio3Tag, 1)
        else
            -- Apply acceleration as a single vector
            local finalAcc = thrustAcc + adjustAcc
            unit.setEngineCommand(t.engines:Union(), { finalAcc:unpack() }, { 0, 0, 0 }, true, true, t.prio1Tag,
                t.prio2Tag, t.prio3Tag, 1)
        end
    end

    ---@param deltaTime number The time since last Flush
    ---@param waypoint Waypoint The next waypoint
    ---@return vec3
    local function move(deltaTime, waypoint)
        local direction = waypoint:DirectionTo()

        local velocity = Velocity()
        local currentSpeed = velocity:len()
        local motionDirection = velocity:normalize()

        local speedLimit = getSpeedLimit(deltaTime, velocity, direction, waypoint)

        local wrongDir = direction:dot(motionDirection) < 0
        local brakeCounter = brakes:Feed(Ternary(wrongDir, 0, speedLimit), currentSpeed)

        local diff = speedLimit - currentSpeed
        wSpeedDiff:Set(calc.Round(calc.Mps2Kph(diff), 1))

        -- Feed the pid with 1/10:th to give it a wider working range.
        speedPid:inject(diff / 10)

        -- Don't let the pid value go outside 0 ... 1 - that would cause the calculated thrust to get
        -- skewed outside its intended values and push us off the path, or make us fall when holding position (if pid gets <0)
        local pidValue = clamp(speedPid:get(), 0, 1)

        wPid:Set(calc.Round(pidValue, 5))

        local acceleration

        -- When we're not moving in the direction we should, counter movement with all we got.
        if wrongDir and currentSpeed > calc.Kph2Mps(20) then
            acceleration = -motionDirection *
                engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-motionDirection) + brakeCounter
        else
            acceleration = direction * pidValue *
                engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(direction) + brakeCounter
        end

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

            visual:DrawNumber(9, chaseData.rabbit)
            visual:DrawNumber(8, chaseData.nearest)
            visual:DrawNumber(0, pos + (acceleration or nullVec):normalize() * 8)
        end
    end

    ---Sets a new state
    ---@param state FlightState
    function s.SetState(state)
        if currentState ~= nil then
            currentState.Leave()
        end

        if state == nil then
            wStateName:Set("No state!")
            return
        else
            wStateName:Set(state:Name())
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
    ---@param currentPos vec3
    ---@param chaseData ChaseData
    ---@return boolean
    function s.CheckPathAlignment(currentPos, chaseData)
        local res = true

        local vel = Velocity()
        local speed = vel:len()

        local toNearest = chaseData.nearest - currentPos

        if speed > 1 then
            res = toNearest:len() < toleranceDistance
        end

        return res
    end

    ---Sets a temporary waypoint
    ---@param waypoint Waypoint
    function s.SetTemporaryWaypoint(waypoint)
        temporaryWaypoint = waypoint
    end

    function s.Update()
        if currentState ~= nil then
            wAcceleration:Set(calc.Round(Acceleration():len(), 2))
            wSpeed:Set(calc.Round(calc.Mps2Kph(Velocity():len()), 1))
            currentState.Update()
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

    s.SetState(Idle.New(s))

    return setmetatable(s, FlightFSM)
end

return FlightFSM
