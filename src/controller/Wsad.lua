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
    local vertical = 0
    local lateral = 0
    local strafe = 0
    local pointDir = Forward()

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

    local function toggleUserLock()
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
    ---@param interval number
    ---@return Vec3
    local function wsadMovement(body, interval)
        local curr = Current()
        -- Put the point 1.5 times the distance we travel per timer interval
        local dist = max(10, vehicle.velocity.Movement():Len() * interval * 1.5)

        local dir = (Forward() * lateral + Right() * strafe - VerticalReferenceVector() * vertical):Normalize()

        local pointInDir = curr + dir * dist
        if body:IsInAtmo(curr) and vertical == 0 then
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

    Task.New("WASD", function()
        local t = 0.1
        local sw = Stopwatch.New()
        sw.Start()
        local wantsToMove = false

        while true do
            local curr = Current()
            local body = universe.ClosestBody(curr)

            if (lateral ~= 0 or vertical ~= 0 or strafe ~= 0) then
                wantsToMove = true
                if sw.Elapsed() > t then
                    sw.Restart()

                    local target = wsadMovement(body, t)
                    local throttleSpeed = getThrottleSpeed()

                    flightCore.GotoTarget(target, false, pointDir, 5, throttleSpeed, throttleSpeed, true)
                end
            elseif wantsToMove then
                wantsToMove = false
                local r = rc.ActivateTempRoute().AddCurrentPos()
                r.Options().Set(PointOptions.LOCK_DIRECTION, { Forward():Unpack() })
                r.Options().Set(PointOptions.MAX_SPEED, constants.flight.standStillSpeed)
                flightCore.StartFlight()
            end

            pub.Publish("ThrottleValue", input.Throttle() * 100)

            coroutine.yield()
        end
    end)

    local function changeVertical(delta)
        vertical = vertical + delta
        if vertical == 0 then
            setWSADHeight()
        end
    end

    input.Register(keys.forward, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        lateral = lateral + 1
    end)

    input.Register(keys.forward, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        lateral = lateral - 1
    end)

    input.Register(keys.backward, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        lateral = lateral - 1
    end)

    input.Register(keys.backward, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        lateral = lateral + 1
    end)

    input.Register(keys.strafeleft, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        strafe = strafe - 1
    end)

    input.Register(keys.strafeleft, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        strafe = strafe + 1
    end)

    input.Register(keys.straferight, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        strafe = strafe + 1
    end)

    input.Register(keys.straferight, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        strafe = strafe - 1
    end)

    input.Register(keys.up, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        changeVertical(1)
    end)

    input.Register(keys.up, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        changeVertical(-1)
    end)

    input.Register(keys.down, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        changeVertical(-1)
    end)

    input.Register(keys.down, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        changeVertical(1)
    end)

    input.Register(keys.yawleft, Criteria.New().OnRepeat(), function()
        if not manualInputEnabled() then return end
        pointDir = flightCore.Turn(turnAngle, Up())
    end)

    input.Register(keys.yawright, Criteria.New().OnRepeat(), function()
        if not manualInputEnabled() then return end
        pointDir = flightCore.Turn(-turnAngle, Up())
    end)

    -- shift + alt + Option9 to switch modes
    input.Register(keys.option9, Criteria.New().LAlt().LShift().OnPress(), toggleUserLock)

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
