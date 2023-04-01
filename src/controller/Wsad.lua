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
local Velocity                = vehicle.velocity.Movement
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
    local wasdHeight = 0
    local vertical = 0
    local longitudal = 0
    local lateral = 0
    local pointDir = Forward()
    local newMovement = false
    local margin = 50

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
        local dist = max(margin, vehicle.velocity.Movement():Len() * interval * 1.5)

        local dir = (Forward() * longitudal + Right() * lateral - VerticalReferenceVector() * vertical):Normalize()

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
        local stopPos = Vec3.zero

        while true do
            local curr = Current()
            local body = universe.ClosestBody(curr)

            local hadNewMovement = newMovement

            wantsToMove = longitudal ~= 0 or vertical ~= 0 or lateral ~= 0
            if not wantsToMove and newMovement then
                stopPos = Current()
            end

            local throttleSpeed = getThrottleSpeed()

            if wantsToMove then
                if sw.Elapsed() > t or newMovement then
                    sw.Restart()

                    local target = wsadMovement(body, t)

                    flightCore.GotoTarget(target, false, pointDir, margin / 2, throttleSpeed, throttleSpeed, true)
                end
            elseif not wantsToMove then
                if newMovement then
                    flightCore.GotoTarget(stopPos, false, pointDir, margin / 2, throttleSpeed, throttleSpeed, true)
                elseif not stopPos:IsZero() and Velocity():Normalize():Dot(stopPos - Current()) >= 0 then
                    flightCore.GotoTarget(Current(), false, pointDir, constants.flight.standStillSpeed, 0,
                        0, false)
                    stopPos = Vec3.zero
                end
            end

            pub.Publish("ThrottleValue", input.Throttle() * 100)

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
            setWSADHeight()
        end
        newMovement = true
    end

    ---@param delta integer
    local function changeLongitudal(delta)
        local previous = longitudal
        longitudal = longitudal + delta
        if previous == 0 and longitudal ~= 0 then
            setWSADHeight()
        end
        newMovement = true
    end

    ---@param delta integer
    local function changeLateral(delta)
        local previous = lateral
        lateral = lateral + delta
        if previous == 0 and lateral ~= 0 then
            setWSADHeight()
        end
        newMovement = true
    end

    input.Register(keys.forward, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        changeLongitudal(1)
    end)

    input.Register(keys.forward, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        changeLongitudal(-1)
    end)

    input.Register(keys.backward, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        changeLongitudal(-1)
    end)

    input.Register(keys.backward, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        changeLongitudal(1)
    end)

    input.Register(keys.strafeleft, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        changeLateral(-1)
    end)

    input.Register(keys.strafeleft, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        changeLateral(1)
    end)

    input.Register(keys.straferight, Criteria.New().OnPress(), function()
        if not manualInputEnabled() then return end
        changeLateral(1)
    end)

    input.Register(keys.straferight, Criteria.New().OnRelease(), function()
        if not manualInputEnabled() then return end
        changeLateral(-1)
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
