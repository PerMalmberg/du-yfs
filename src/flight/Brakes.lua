local vehicle = require("abstraction/Vehicle"):New()
local calc = require("util/Calc")
local universe = require("universe/Universe").Instance()
local nullVec = require("math/Vec3").New()
local PID = require("cpml/pid")
local IsInAtmo = vehicle.world.IsInAtmo
local TotalMass = vehicle.mass.Total
local Velocity = vehicle.velocity.Movement
local GravityDirection = vehicle.world.GravityDirection
local G = vehicle.world.G
local utils = require("cpml/utils")
local pub = require("util/PubSub").Instance()
local clamp = utils.clamp
local max = math.max


local atmoBrakeCutoffSpeed = calc.Kph2Mps(360) -- Speed limit under which atmospheric brakes become less effective (down to 10m/s [36km/h] where they give 0.1 of max)
local atmoBrakeEfficiencyFactor = 0.6
local spaceEfficiencyFactor = 0.9 -- Reduced from one to counter brake PID not reacting immediately, thus inducing a delay and subsequent overshoot.

---@class Brake
---@field Instance fun() Brake
---@field Forced fun(enable:boolean)
---@field BrakeUpdate fun()
---@field BrakeFlush fun()
---@field GravityInfluencedAvailableDeceleration fun():number
---@field AvailableDeceleration fun():number
---@field BrakeEfficiency fun(inAtmo:boolean, speed:number):number
---@field Feed fun(targetSpeed:number, currentSpeed:number)

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
    local pidLowSpeed = PID(0.1, 0, 0.01)
    local deceleration = 0
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

    local function finalDeceleration()
        if s.forced then
            return -Velocity():Normalize() * rawAvailableDeceleration()
        else
            return -Velocity():Normalize() * deceleration
        end
    end

    function s:BrakeUpdate()
        s.totalMass = TotalMass()
        brakeData.maxDeceleration = rawAvailableDeceleration()
        brakeData.currentDeceleration = construct.getCurrentBrake() / s.totalMass
        pub.Publish("BrakeData", brakeData)
    end

    local function brakeCounter()
        --[[ From NQ Support:
            "The speed is projected on the horizontal plane of the construct. And we add a brake force in that plane
            in the opposite direction of that projected speed, which induces a vertical force when the ship has a pitch."

            So to counter this stupidity (why not apply the brake force opposite of the velocity?!) we calculate the resulting
            brake acceleration on the vertical vector and add that to the thrust vector.
        ]]
        local res = nullVec
        if IsInAtmo() then
            res = finalDeceleration():ProjectOn(universe:VerticalReferenceVector())
        end

        return res
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

    ---Gets the unadjusted available deceleration
    ---@return number
    function s.AvailableDeceleration()
        return rawAvailableDeceleration()
    end

    ---@param targetSpeed number The desired speed
    ---@param currentSpeed number The current speed
    ---@return Vec3 The thrust needed to counter the thrust induced by the braking operation
    function s.Feed(targetSpeed, currentSpeed)

        local diff = targetSpeed - currentSpeed
        diff = -diff -- Negate to make PID become positive when we have too high speed.
        pidHighSpeed:inject(diff)
        pidLowSpeed:inject(diff)

        local brakeValue
        if currentSpeed > calc.Kph2Mps(100) then
            brakeValue = clamp(pidHighSpeed:get(), 0, 1)
        else
            brakeValue = clamp(pidLowSpeed:get(), 0, 1)
        end

        if currentSpeed <= targetSpeed then
            pidHighSpeed:reset()
            pidLowSpeed:reset()
            brakeValue = 0
        end

        brakeData.pid = brakeValue

        deceleration = brakeValue * rawAvailableDeceleration()

        return brakeCounter()
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

    instance = setmetatable(s, Brake)
    return instance
end

return Brake
