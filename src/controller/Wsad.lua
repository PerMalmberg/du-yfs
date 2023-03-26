local Criteria                = require("input/Criteria")
local PointOptions            = require("flight/route/PointOptions")
local Vec3                    = require("math/Vec3")
local Task                    = require("system/Task")
local log                     = require("debug/Log")()
local vehicle                 = require("abstraction/Vehicle").New()
local calc                    = require("util/Calc")
local universe                = require("universe/Universe").Instance()
local keys                    = require("input/Keys")
local constants               = require("YFSConstants")
local Stopwatch               = require("system/Stopwatch")
local input                   = require("input/Input").Instance()
local pub                     = require("util/PubSub").Instance()
local VerticalReferenceVector = universe.VerticalReferenceVector
local MaxSpeed                = vehicle.speed.MaxSpeed
local Clamp                   = calc.Clamp
local Current                 = vehicle.position.Current
local Forward                 = vehicle.orientation.Forward
local Right                   = vehicle.orientation.Right
local Up                      = vehicle.orientation.Up
local max                     = math.max

---@class Wsad
---@field New fun(flightcore:FlightCore):Wsad

local Wsad                    = {}
Wsad.__index                  = Wsad

---@param flightCore FlightCore
---@param cmd CommandLine
---@param settings Settings
---@return Wsad
function Wsad.New(flightCore, cmd, settings)
    local s = {}
    local turnAngle = 1
    local wsadDirection = { longLat = Vec3.zero, vert = Vec3.zero }
    local lockDir = Vec3.zero
    local wasdHeight = 0

    input.SetThrottle(1) -- Start at max speed
    local throttleStep = settings.Get("throttleStep", constants.flight.throttleStep) / 100
    ---@cast throttleStep number
    input.SetThrottleStep(throttleStep)

    settings.RegisterCallback("throttleStep", function(step)
        input.SetThrottleStep(step / 100)
    end)

    local rc = flightCore.GetRouteController()

    local function checkControlMode()
        if unit.isMouseControlActivated() == 1 or unit.isMouseDirectControlActivated() == 1 or unit.isMouseVirtualJoystickActivated() == 1 then
            log:Error("Must use control scheme 'Keyboard'")
            unit.exit()
        end
    end

    checkControlMode()

    local function manualInputEnabled()
        return player.isFrozen() == 1
    end

    local function lockUser()
        player.freeze(true)
        log:Info("Player locked and auto shutdown disabled.")
    end

    local function toggleUSerLock()
        if manualInputEnabled() then
            player.freeze(false)
            log:Info("Player released and auto shutdown enabled.")
        else
            lockUser()
        end
    end

    local function getThrottleSpeed()
        return MaxSpeed() * input.Throttle()
    end

    ---@param body Body
    ---@param direction {longLat:Vec3, vert:Vec3}
    ---@param interval number
    ---@return Vec3
    local function wsadMovement(body, direction, interval)
        local curr = Current()
        -- Put the point 1.5 times the distance we travel per timer interval
        local dist = max(10, vehicle.velocity.Movement():Len() * interval * 1.5)

        local dir = (direction.longLat + direction.vert):Normalize()

        local pointInDir = curr + dir * dist
        if body:IsInAtmo(curr) and direction.vert:IsZero() then
            -- Find the direction from body center to forward point and calculate a new point with same
            -- height as the movement started at so that we move along the curvature of the body.
            return body.Geography.Center + (pointInDir - body.Geography.Center):NormalizeInPlace() * wasdHeight
        end

        return Current() + dir * dist
    end

    local function setWSADHeight()
        local curr = Current()
        local body = universe.ClosestBody(curr)
        wasdHeight = (curr - body.Geography.Center):Len()
    end

    ---@param longLat Vec3
    ---@param vert Vec3
    ---@param lockDirection Vec3
    local function activateManualMovement(longLat, vert, lockDirection)
        lockDir = lockDirection

        if not longLat:IsZero() then
            setWSADHeight()
            wsadDirection.longLat = longLat
        end

        if not vert:IsZero() then
            wsadDirection.vert = vert
            setWSADHeight()
        end
    end

    ---@param longLat boolean
    ---@param vert boolean
    local function comeToStandStill(longLat, vert)
        if longLat then
            wsadDirection.longLat = Vec3.zero
        end

        if vert then
            wsadDirection.vert = Vec3.zero
            setWSADHeight()
        end

        if wsadDirection.longLat:IsZero() and wsadDirection.vert:IsZero() then
            local r = rc.ActivateTempRoute().AddCurrentPos()
            r.Options().Set(PointOptions.LOCK_DIRECTION, { Forward():Unpack() })
            r.Options().Set(PointOptions.MAX_SPEED, constants.flight.standStillSpeed)
            flightCore.StartFlight()
        end
    end

    Task.New("WASD", function()
        local t = 0.1
        local sw = Stopwatch.New()
        sw.Start()

        while true do
            local curr = Current()
            local body = universe.ClosestBody(curr)

            if (not wsadDirection.longLat:IsZero() or not wsadDirection.vert:IsZero()) and sw.Elapsed() > t then
                sw.Restart()

                local target = wsadMovement(body, wsadDirection, t)
                local throttleSpeed = getThrottleSpeed()

                flightCore.GotoTarget(target, false, lockDir, 5, throttleSpeed, throttleSpeed, true)
            end

            pub.Publish("ThrottleValue", input.Throttle() * 100)

            coroutine.yield()
        end
    end)

    input.Register(keys.forward, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        activateManualMovement(Forward(), Vec3.zero, Forward())
    end)

    input.Register(keys.forward, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        comeToStandStill(true, false)
    end)

    input.Register(keys.backward, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        activateManualMovement(-Forward(), Vec3.zero, Forward())
    end)

    input.Register(keys.backward, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        comeToStandStill(true, false)
    end)

    input.Register(keys.strafeleft, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        activateManualMovement(-Right(), Vec3.zero, Forward())
    end)

    input.Register(keys.strafeleft, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        comeToStandStill(true, false)
    end)

    input.Register(keys.straferight, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        activateManualMovement(Right(), Vec3.zero, Forward())
    end)

    input.Register(keys.straferight, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        comeToStandStill(true, false)
    end)

    input.Register(keys.up, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        activateManualMovement(Vec3.zero, -VerticalReferenceVector(), Forward())
    end)

    input.Register(keys.up, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        comeToStandStill(false, true)
    end)

    input.Register(keys.down, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        activateManualMovement(Vec3.zero, VerticalReferenceVector(), Forward())
    end)

    input.Register(keys.down, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        comeToStandStill(false, true)
    end)

    input.Register(keys.yawleft, Criteria.New().OnRepeat(), function()
        if not manualInputEnabled() then return end
        local dir = flightCore.Turn(turnAngle, Up())
        if input.IsPressed(keys.backward) then
            activateManualMovement(-dir, Vec3.zero, dir)
        elseif input.IsPressed(keys.forward) then
            activateManualMovement(dir, Vec3.zero, dir)
        else
            activateManualMovement(Vec3.zero, Vec3.zero, dir)
        end
    end)

    input.Register(keys.yawright, Criteria.New().OnRepeat(), function()
        if not manualInputEnabled() then return end
        local dir = flightCore.Turn(-turnAngle, Up())

        if input.IsPressed(keys.backward) then
            activateManualMovement(-dir, Vec3.zero, dir)
        elseif input.IsPressed(keys.forward) then
            activateManualMovement(dir, Vec3.zero, dir)
        else
            activateManualMovement(Vec3.zero, Vec3.zero, dir)
        end
    end)

    -- shift + alt + Option9 to switch modes
    input.Register(keys.option9, Criteria.New().LAlt().LShift().OnPress(), toggleUSerLock)

    cmd.Accept("turn-angle",
        ---@param data {commandValue:number}
        function(data)
            turnAngle = Clamp(data.commandValue, 0, 360)
            log:Info("Turn angle: ", turnAngle, "°")
        end).AsNumber().Mandatory()

    if settings.Get("manualControlOnStartup", false) then
        log:Info("Manual control on startup active.")
        lockUser()
    end

    return setmetatable(s, Wsad)
end

return Wsad
