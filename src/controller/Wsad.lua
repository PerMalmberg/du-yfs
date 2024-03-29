require("GlobalTypes")
local s                                = require("Singletons")
local log, universe, input, pub, gateControl,
constants, calc, keys, floor, gateCtrl =
    s.log, s.universe, s.input, s.pub, s.gateCtrl, s.constants, s.calc, s.keys, s.floorDetector, s.gateCtrl
local VerticalReferenceVector          = universe.VerticalReferenceVector
local Sign                             = calc.Sign
local NF                               = function() return not IsFrozen() end
local Clamp                            = calc.Clamp

local defaultMargin                    = constants.flight.defaultMargin

---@class Wsad
---@field New fun(flightcore:FlightCore):Wsad

local Wsad                             = {}
Wsad.__index                           = Wsad

---@param fsm FlightFSM
---@param flightCore FlightCore
---@param settings Settings
---@param access Access
---@return Wsad
function Wsad.New(fsm, flightCore, settings, access)
    local s = {}
    local turnAngle = settings.Number("turnAngle")
    local desiredAltitude = 0
    local vertical = 0
    local longitudal = 0
    local lateral = 0
    local pointDir = Vec3.zero
    local newMovement = false
    local stopVerticalMovement = false
    local yawSmoothStop = false
    local yawStopSign = 0
    local plane = Plane.NewByVertialReference()
    local stopPos = Vec3.zero
    local forwardToggle = false
    local allowForwardToggle = settings.Boolean("allowForwardToggle")

    settings.Callback("allowForwardToggle", function(v)
        allowForwardToggle = v
    end)

    local function getForwardToggle()
        return forwardToggle and allowForwardToggle
    end


    input.SetThrottle(1) -- Start at max speed
    local throttleStep = settings.Get("throttleStep", constants.flight.throttleStep) / 100
    ---@cast throttleStep number
    input.SetThrottleStep(throttleStep)

    settings.Callback("throttleStep", function(step)
        input.SetThrottleStep(step / 100)
    end)

    local function checkControlMode()
        if unit.isMouseControlActivated() or unit.isMouseDirectControlActivated() or unit.isMouseVirtualJoystickActivated() then
            log.Error("Must use control scheme 'Keyboard'")
            unit.exit()
        end
    end

    checkControlMode()

    local function lockUser()
        if not access.AllowsManualControl() then
            log.Error("Manual control not authorized")
            return
        end

        player.freeze(true)
        log.Info("Manual control enabled, auto shutdown disabled.")
    end

    local function toggleUserLock()
        if IsFrozen() then
            player.freeze(false)
            log.Info("Manual control disabled, auto shutdown enabled.")
        else
            lockUser()
        end
    end

    local function getThrottleSpeed()
        return MaxSpeed() * input.Throttle()
    end

    ---@return number
    local function altitude()
        local curr = Current()
        local body = universe.ClosestBody(curr)
        return (curr - body.Geography.Center):Len()
    end

    local function monitorHeight()
        desiredAltitude = altitude()
        stopVerticalMovement = true
    end

    ---@param body Body
    ---@return Vec3
    local function movement(body)
        local curr = Current()
        -- Put the point 50 m ahead
        local dist = 50

        local dir = (plane.Forward() * (getForwardToggle() and 1 or longitudal)
                + plane.Right() * lateral
                + plane.Up() * vertical)
            :Normalize()

        if body:IsInAtmo(curr) and vertical == 0 then
            -- As we meassure only periodically, we can't make the threshold too small. 0.2m/s was too small, we can miss that when moving fast.
            if stopVerticalMovement and Velocity():ProjectOn(-VerticalReferenceVector()):Len() < 0.5 then
                desiredAltitude = altitude()
                stopVerticalMovement = false
            end


            -- Find the direction from body center to forward point and calculate a new point with same
            -- height as the movement started at so that we move along the curvature of the body.
            local pointInDir = curr + dir * dist
            local center = body.Geography.Center
            return center + (pointInDir - center):NormalizeInPlace() * desiredAltitude
        end

        return Current() + dir * dist
    end

    Task.New("WASD", function()
        local t = 0.1
        local sw = Stopwatch.New()
        sw.Start()
        local wantsToMove = false

        pub.RegisterBool("ResetWSAD", function(_, _)
            stopPos = Vec3.zero
            wantsToMove = false
            pointDir = Vec3.zero
            forwardToggle = false
        end)

        pub.RegisterTable("ForwardDirectionChanged",
            ---@param _ string
            ---@param value Vec3
            function(_, value)
                pointDir = value
            end)

        pub.RegisterTable("YawData",
            ---@param value {speed:number}
            function(_, value)
                if yawSmoothStop then
                    if Sign(value.speed) ~= yawStopSign then
                        flightCore.AlignTo(Current() + plane.Forward() * 1000)
                        yawSmoothStop = false
                    end
                end
                yawStopSign = Sign(value.speed)
            end)

        monitorHeight()

        while true do
            local curr = Current()
            local body = universe.ClosestBody(curr)

            local hadNewMovement = newMovement

            wantsToMove = getForwardToggle() or longitudal ~= 0 or vertical ~= 0 or lateral ~= 0
            if not wantsToMove and newMovement then
                stopPos = Current()
            end

            if IsFrozen() then
                if wantsToMove then
                    gateControl.Enable(false)
                    if pointDir:IsZero() then
                        -- Recovery after running a route
                        pointDir = plane.Forward()
                    end

                    if sw.Elapsed() > t or newMovement then
                        sw.Restart()

                        local throttleSpeed = getThrottleSpeed()
                        local target = movement(body)
                        flightCore.GotoTarget(target, pointDir, defaultMargin, throttleSpeed, throttleSpeed, true, true)
                    end
                else
                    if newMovement then
                        flightCore.GotoTarget(stopPos, pointDir, defaultMargin, 0, construct.getMaxSpeed(), true, true)
                    elseif not stopPos:IsZero() and Velocity():Normalize():Dot(stopPos - curr) >= 0 then
                        local holdMargin = defaultMargin
                        flightCore.GotoTarget(Current(), pointDir, holdMargin, calc.Kph2Mps(2), 0, false, true)
                        stopPos = Vec3.zero
                    end
                end
            else
                -- Ensure we keep throttle at max when not in manual control.
                input.SetThrottle(1)
            end

            -- Reset this only if it was active at the start of the loop.
            if hadNewMovement then
                newMovement = false
            end

            coroutine.yield()
        end
    end)

    local function change(value, delta)
        forwardToggle = false

        local prev = value
        value = Clamp(value + delta, -1, 1)

        if value == 0 then
            monitorHeight()
        end

        newMovement = value ~= prev
        gateControl.Enable(false)

        return value
    end

    ---@param delta integer
    local function changeVertical(delta)
        vertical = change(vertical, delta)
    end

    ---@param delta integer
    local function changeLongitudal(delta)
        longitudal = change(longitudal, delta)
    end

    ---@param delta integer
    local function changeLateral(delta)
        lateral = change(lateral, delta)
    end

    local function NewIgnoreBoth()
        return Criteria.New().IgnoreLCtrl().IgnoreLShift()
    end

    local function fwd() changeLongitudal(1) end
    local function back() changeLongitudal(-1) end

    input.Register(keys.forward, NewIgnoreBoth().OnRepeat(), fwd)
    input.Register(keys.forward, NewIgnoreBoth().OnRelease(), back)
    input.Register(keys.backward, NewIgnoreBoth().OnRepeat(), back)
    input.Register(keys.backward, NewIgnoreBoth().OnRelease(), fwd)

    local function left() changeLateral(-1) end
    local function right() changeLateral(1) end

    input.RegisterMany({ keys.strafeleft, keys.left }, NewIgnoreBoth().OnRepeat(), left)
    input.RegisterMany({ keys.strafeleft, keys.left }, NewIgnoreBoth().OnRelease(), right)
    input.RegisterMany({ keys.straferight, keys.right }, NewIgnoreBoth().OnRepeat(), right)
    input.RegisterMany({ keys.straferight, keys.right }, NewIgnoreBoth().OnRelease(), left)

    local function up() changeVertical(1) end
    local function down() changeVertical(-1) end

    input.Register(keys.up, NewIgnoreBoth().OnRepeat(), up)
    input.Register(keys.up, NewIgnoreBoth().OnRelease(), down)
    input.Register(keys.down, NewIgnoreBoth().OnRepeat(), down)
    input.Register(keys.down, NewIgnoreBoth().OnRelease(), up)

    local function turn(positive)
        if NF() then return end
        pointDir = flightCore.Turn(positive and turnAngle or -turnAngle, plane.Up())
    end

    input.Register(keys.yawleft, NewIgnoreBoth().OnRepeat(), function()
        turn(true)
    end)

    input.Register(keys.yawright, NewIgnoreBoth().OnRepeat(), function()
        turn(false)
    end)

    input.RegisterMany({ keys.yawleft, keys.yawright }, NewIgnoreBoth().OnRelease(),
        function()
            if NF() then return end
            yawSmoothStop = true
        end)

    local function booster(on)
        if NF() then return end
        fsm.SetBooster(on)
    end

    input.Register(keys.brake, Criteria.New().LCtrl().OnPress(), function()
        forwardToggle = false
        newMovement = true
        pointDir = plane.Forward()
        stopPos = Current()
    end)

    input.Register(keys.booster, NewIgnoreBoth().OnPress(), function() booster(true) end)
    input.Register(keys.booster, NewIgnoreBoth().OnRelease(), function() booster(false) end)

    -- shift + alt + Option9 to switch modes
    input.Register(keys.option9, Criteria.New().LShift().OnPress(), toggleUserLock)

    input.Register(keys.stopengines, NewIgnoreBoth().OnPress(), function()
        if NF() then return end
        forwardToggle = not forwardToggle
        newMovement = true
    end)

    if settings.Get("manualControlOnStartup", false) then
        log.Info("Manual control on startup active.")
        lockUser()
    end

    settings.Callback("turnAngle",
        ---@param angle number
        function(angle)
            turnAngle = angle
        end)

    return setmetatable(s, Wsad)
end

return Wsad
