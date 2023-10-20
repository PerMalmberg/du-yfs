require("abstraction/Vehicle")
local calc = require("util/Calc")
local nullVec = require("math/Vec3").New()
local PID = require("cpml/pid")
local pub = require("util/PubSub").Instance()
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
---@field AvailableDeceleration fun():number
---@field BrakeEfficiency fun(inAtmo:boolean, speed:number):number
---@field EffectiveBrakeDeceleration fun():number
---@field Feed fun(desiredDir:Vec3, targetSpeed:number)
---@field Active fun():boolean

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
    local brakeData = { maxDeceleration = 0, currentDeceleration = 0, pid = 0 } ---@type BrakeData

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

    ---Gets the unadjusted available deceleration
    ---@return number
    function s.AvailableDeceleration()
        return rawAvailableDeceleration()
    end

    ---@param desiredDir Vec3 Direction we want to move in
    ---@param targetSpeed number The desired speed
    function s.Feed(desiredDir, targetSpeed)
        local movementDir, currentSpeed = Velocity():NormalizeLen()
        if desiredDir:AngleToDeg(movementDir) > 45 then
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
    ---@return number
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

    ---Gets the max brake acceleration
    ---@return number
    function s.MaxBrakeAcc()
        return rawAvailableDeceleration()
    end

    instance = setmetatable(s, Brake)
    return instance
end

return Brake
