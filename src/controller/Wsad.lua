local Criteria                = require("input/Criteria")
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
local defaultMargin           = constants.flight.defaultMargin
local Velocity                = vehicle.velocity.Movement
local VerticalReferenceVector = universe.VerticalReferenceVector
local MaxSpeed                = vehicle.speed.MaxSpeed
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
    local turnAngle = settings.Number("turnAngle")
    local desiredAltitude = 0
    local vertical = 0
    local longitudal = 0
    local lateral = 0
    local pointDir = Forward()
    local newMovement = false
    local stopVerticalMovement = false

    input.SetThrottle(1) -- Start at max speed
    local throttleStep = settings.Get("throttleStep", constants.flight.throttleStep) / 100
    ---@cast throttleStep number
    input.SetThrottleStep(throttleStep)

    settings.RegisterCallback("throttleStep", function(step)
        input.SetThrottleStep(step / 100)
    end)

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

    ---@return number
    local function getHeight()
        local curr = Current()
        local body = universe.ClosestBody(curr)
        return (curr - body.Geography.Center):Len()
    end

    local function monitorHeight()
        desiredAltitude = getHeight()
        stopVerticalMovement = true
    end

    ---@param body Body
    ---@param interval number
    ---@return Vec3
    local function movement(body, interval)
        local curr = Current()
        -- Put the point 1.5 times the distance we travel per timer interval
        local dist = max(50, vehicle.velocity.Movement():Len() * interval * 1.5)

        local dir = (Forward() * longitudal + Right() * lateral + Up() * vertical):Normalize()

        if body:IsInAtmo(curr) and vertical == 0 then
            local currHeight = getHeight()
            -- As we meassure only periodically, we can't make the threshold too small. 0.2m/s was too small, we can miss that when moving fast.
            if stopVerticalMovement and Velocity():ProjectOn(-VerticalReferenceVector()):Len() < 0.5 then
                desiredAltitude = currHeight
                stopVerticalMovement = false
            end

            -- Find the direction from body center to forward point and calculate a new point with same
            -- height as the movement started at so that we move along the curvature of the body.
            local pointInDir = curr + dir * dist
            return body.Geography.Center + (pointInDir - body.Geography.Center):NormalizeInPlace() * desiredAltitude
        end

        return Current() + dir * dist
    end

    Task.New("WASD", function()
        local t = 0.1
        local sw = Stopwatch.New()
        sw.Start()
        local wantsToMove = false
        local stopPos = Vec3.zero

        pub.RegisterBool("RouteActivated", function(_, _)
            stopPos = Vec3.zero
            wantsToMove = false
        end)

        while true do
            local curr = Current()
            local body = universe.ClosestBody(curr)

            local hadNewMovement = newMovement

            wantsToMove = longitudal ~= 0 or vertical ~= 0 or lateral ~= 0
            if not wantsToMove and newMovement then
                stopPos = Current()
            end

            if manualInputEnabled() then
                if wantsToMove then
                    if sw.Elapsed() > t or newMovement then
                        sw.Restart()

                        local throttleSpeed = getThrottleSpeed()
                        local target = movement(body, t)
                        flightCore.GotoTarget(target, pointDir, defaultMargin, throttleSpeed, throttleSpeed, true)
                    end
                else
                    if newMovement then
                        flightCore.GotoTarget(stopPos, pointDir, defaultMargin, 0, construct.getMaxSpeed(), true)
                    elseif not stopPos:IsZero() and Velocity():Normalize():Dot(stopPos - curr) >= 0 then
                        local holdMargin = defaultMargin
                        flightCore.GotoTarget(Current(), pointDir, holdMargin, calc.Kph2Mps(2), 0, false)
                        stopPos = Vec3.zero
                    end
                end

                pub.Publish("ThrottleValue", input.Throttle() * 100)
            end

            -- Reset this only if it was active at the start of the loop.
            if hadNewMovement then
                newMovement = false
            end

            coroutine.yield()
        end
    end)

    ---@param delta integer
    local function changeVertical(delta)
        vertical = vertical + delta
        if vertical == 0 then
            monitorHeight()
        end
        newMovement = true
    end

    ---@param delta integer
    local function changeLongitudal(delta)
        local previous = longitudal
        longitudal = longitudal + delta
        if previous == 0 and longitudal ~= 0 then
            monitorHeight()
        end
        newMovement = true
    end

    ---@param delta integer
    local function changeLateral(delta)
        local previous = lateral
        lateral = lateral + delta
        if previous == 0 and lateral ~= 0 then
            monitorHeight()
        end
        newMovement = true
    end

    input.Register(keys.forward, Criteria.New().OnPress(), function()
        changeLongitudal(1)
    end)

    input.Register(keys.forward, Criteria.New().OnRelease(), function()
        changeLongitudal(-1)
    end)

    input.Register(keys.backward, Criteria.New().OnPress(), function()
        changeLongitudal(-1)
    end)

    input.Register(keys.backward, Criteria.New().OnRelease(), function()
        changeLongitudal(1)
    end)

    input.Register(keys.strafeleft, Criteria.New().OnPress(), function()
        changeLateral(-1)
    end)

    input.Register(keys.strafeleft, Criteria.New().OnRelease(), function()
        changeLateral(1)
    end)

    input.Register(keys.straferight, Criteria.New().OnPress(), function()
        changeLateral(1)
    end)

    input.Register(keys.straferight, Criteria.New().OnRelease(), function()
        changeLateral(-1)
    end)

    input.Register(keys.up, Criteria.New().OnPress(), function()
        changeVertical(1)
    end)

    input.Register(keys.up, Criteria.New().OnRelease(), function()
        changeVertical(-1)
    end)

    input.Register(keys.down, Criteria.New().OnPress(), function()
        changeVertical(-1)
    end)

    input.Register(keys.down, Criteria.New().OnRelease(), function()
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

    if settings.Get("manualControlOnStartup", false) then
        log:Info("Manual control on startup active.")
        lockUser()
    end

    pub.RegisterTable("ForwardDirectionChanged",
        ---@param _ string
        ---@param value Vec3
        function(_, value)
            pointDir = value
        end)

    settings.RegisterCallback("turnAngle",
        ---@param angle number
        function(angle)
            turnAngle = angle
        end)

    return setmetatable(s, Wsad)
end

return Wsad
