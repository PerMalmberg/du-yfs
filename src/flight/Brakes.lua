require("abstraction/Vehicle")
local calc, nullVec, PID, pub, autoBrakeTimer = require("util/Calc"), require("math/Vec3").New(), require("cpml/pid"),
    require("util/PubSub").Instance(), require("system/Stopwatch").New()
local Clamp = calc.Clamp
local max = math.max

local atmoBrakeCutoffSpeed = calc.Kph2Mps(360) -- Speed limit under which atmospheric brakes become less effective (down to 10m/s [36km/h] where they give 0.1 of max)
local atmoBrakeEfficiencyFactor = 0.9          -- Kept at 0.9
local spaceEfficiencyFactor = 0.9              -- Reduced from one to counter brake PID not reacting immediately, thus inducing a delay and subsequent overshoot.

---@class Brake
---@field Instance fun() Brake
---@field Forced fun(enable:boolean)
---@field BrakeUpdate fun()
---@field BrakeFlush fun()
---@field MaxBrakeAcc fun():number
---@field GravityInfluencedAvailableDeceleration fun():number
---@field MaxSeenGravityInfluencedAvailableAtmoDeceleration fun():number
---@field BrakeEfficiency fun(inAtmo:boolean, speed:number):number
---@field EffectiveBrakeDeceleration fun():number
---@field Feed fun(desiredMovementDir:Vec3, accelerationDir:Vec3, targetSpeed:number)
---@field Active fun():boolean
---@field SetAutoBrakeAngle fun(angle:number)
---@field SetAutoBrakeDelay fun(delay:number)
---@field CalcMaxAllowedSpeed fun(distance:number, endSpeed:number, availableBrakeDeceleration:number|nil):number


local Brake = {}
Brake.__index = Brake

local instance

---Gets the brake instance
---@return Brake
function Brake.Instance()
    if instance then
        return instance
    end

    local pidHighSpeed = PID(1, 0, 0.01)
    local pidLowSpeed = PID(0.1, 0.0, 1)
    local deceleration = nullVec
    local maxSeenBrakeAtmoAcc = 0
    local _100kmph = calc.Kph2Mps(100)
    local brakeData = { maxDeceleration = 0, currentDeceleration = 0, pid = 0, setAutoBrakeAngle = 0, autoBrakeAngle = 0 } ---@type BrakeData
    local autoBrakeAngle = 45
    local autoBrakeDelay = 1

    local s = {
        engaged = false,
        forced = false,
        totalMass = TotalMass()
    }

    ---Returns the deceleration the construct is capable of in the given movement.
    ---@return number Deceleration
    local function rawAvailableDeceleration()
        -- F = m * a => a = F / m
        return construct.getMaxBrake() / s.totalMass
    end

    ---@return Vec3
    local function finalDeceleration()
        if s.forced then
            return -Velocity():Normalize() * rawAvailableDeceleration()
        else
            return deceleration
        end
    end

    function s:BrakeUpdate()
        s.totalMass = TotalMass()
        local raw = rawAvailableDeceleration()
        brakeData.maxDeceleration = raw
        brakeData.currentDeceleration = construct.getCurrentBrake() / s.totalMass
        if IsInAtmo() then
            maxSeenBrakeAtmoAcc = max(raw, maxSeenBrakeAtmoAcc)
        end
        brakeData.setAutoBrakeAngle = autoBrakeAngle
        pub.Publish("BrakeData", brakeData)
    end

    ---Enables/disables forced brakes
    ---@param on boolean
    function s.Forced(on)
        s.forced = on
    end

    function s.BrakeFlush()
        -- The brake vector must point against the direction of travel.
        local brakeVector = finalDeceleration()
        unit.setEngineCommand("brake", { brakeVector:Unpack() }, { 0, 0, 0 }, true, true, "", "", "", 0.001)
    end

    ---Gets the available brake deceleration, after taking gravity into account
    ---@return number
    function s.GravityInfluencedAvailableDeceleration()
        local dot = GravityDirection():Dot(Velocity():Normalize())
        local movingTowardsGravityWell = dot > 0
        local influence = calc.Ternary(movingTowardsGravityWell, -1, 1)
        -- Might not be enough brakes to counter gravity so don't go below 0
        return max(0, rawAvailableDeceleration() + influence * dot * G())
    end

    function s.MaxSeenGravityInfluencedAvailableAtmoDeceleration()
        local dot = GravityDirection():Dot(Velocity():Normalize())
        local movingTowardsGravityWell = dot > 0
        local influence = calc.Ternary(movingTowardsGravityWell, -1, 1)
        -- Might not be enough brakes to counter gravity so don't go below 0
        return max(0, maxSeenBrakeAtmoAcc + influence * dot * G())
    end

    ---@param desiredMovementDir Vec3 The direction we want to move
    ---@param accelerationDir Vec3 Current acceleration vector
    ---@param targetSpeed number The desired speed
    function s.Feed(desiredMovementDir, accelerationDir, targetSpeed)
        local movementDir, currentSpeed = Velocity():NormalizeLen()

        -- Prefer acceleration over desired movement dir
        if not accelerationDir:IsZero() then
            brakeData.autoBrakeAngle = accelerationDir:AngleToDeg(movementDir)
        elseif not desiredMovementDir:IsZero() then
            brakeData.autoBrakeAngle = desiredMovementDir:AngleToDeg(movementDir)
        else
            brakeData.autoBrakeAngle = 0
        end

        if brakeData.autoBrakeAngle > autoBrakeAngle then
            autoBrakeTimer.Start()
        else
            autoBrakeTimer.Reset()
        end

        if autoBrakeTimer.Elapsed() > autoBrakeDelay then
            targetSpeed = 0
        end

        local diff = currentSpeed - targetSpeed -- make PID become positive when we have too high speed.
        pidHighSpeed:inject(diff)
        pidLowSpeed:inject(diff)

        local pid = currentSpeed > _100kmph and pidHighSpeed or pidLowSpeed

        local brakeValue = Clamp(pid:get(), 0, 1)

        if currentSpeed <= targetSpeed then
            pidHighSpeed:reset()
            pidLowSpeed:reset()
            brakeValue = 0
        end

        brakeData.pid = brakeValue

        deceleration = -movementDir * brakeValue * rawAvailableDeceleration()
    end

    function s.Active()
        return brakeData.pid > 0
    end

    ---Gets the brake efficiency to use
    ---@param inAtmo boolean
    ---@param speed number
    ---@return number
    function s.BrakeEfficiency(inAtmo, speed)
        if not inAtmo then
            return spaceEfficiencyFactor
        end

        if speed <= atmoBrakeCutoffSpeed then
            return 0.1
        else
            return atmoBrakeEfficiencyFactor
        end
    end

    --- Returns the current effective brake deceleration
    ---@return number # The deceleration, a negative value
    function s.EffectiveBrakeDeceleration()
        local currentSpeed = Velocity():Len()
        local inAtmo = IsInAtmo()
        local brakeEfficiency = s.BrakeEfficiency(inAtmo, currentSpeed)

        local atmoDensity = AtmoDensity()
        if atmoDensity > 0 then
            brakeEfficiency = brakeEfficiency * atmoDensity
        end

        local availableBrakeDeceleration = -s.GravityInfluencedAvailableDeceleration() * brakeEfficiency

        if inAtmo and currentSpeed < calc.Kph2Mps(3) then
            -- When standing (nearly) still in atmo, assume brakes gives current g of brake acceleration (brake API gives a 0 as response in this case)
            local maxSeen = s.MaxSeenGravityInfluencedAvailableAtmoDeceleration()
            availableBrakeDeceleration = -max(maxSeen, G())
        end

        return availableBrakeDeceleration
    end

    --- Calculates the max allowed speed we may have while still being able to decelerate to the endSpeed
    ---@param distance number Remaining distance to target
    ---@param endSpeed number Desired speed when reaching target
    ---@param brakeAcc number|nil Brake acceleration, or nil to use the currently effective deceleration. Remember to pass in a negative number.
    ---@return number
    function s.CalcMaxAllowedSpeed(distance, endSpeed, brakeAcc)
        -- v^2 = v0^2 + 2a*d
        -- v0^2 = v^2 - 2a*d
        -- v0 = sqrt(v^2 - 2ad)

        brakeAcc = brakeAcc or s.EffectiveBrakeDeceleration()

        local v0 = (endSpeed * endSpeed - 2 * brakeAcc * distance) ^ 0.5
        return v0
    end

    ---Gets the max brake acceleration
    ---@return number
    function s.MaxBrakeAcc()
        return rawAvailableDeceleration()
    end

    ---Sets the auto brake angle
    ---@param angle number
    function s.SetAutoBrakeAngle(angle)
        autoBrakeAngle = angle
    end

    ---Sets the auto brake angle
    ---@param delay number
    function s.SetAutoBrakeDelay(delay)
        autoBrakeDelay = delay
    end

    instance = setmetatable(s, Brake)
    return instance
end

return Brake
