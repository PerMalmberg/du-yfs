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

local Brake = {}
Brake.__index = Brake

local instance

function Brake.Instance()
    if instance then
        return instance
    end

    local pid = PID(1, 0, 0.01)
    local deceleration = 0
    local brakeData = { maxDeceleration = 0, currentDeceleration = 0, pid = 0 } ---@type BrakeData

    local s = {
        engaged = false,
        forced = false,
        totalMass = TotalMass()
    }

    ---Returns the deceleration the construct is capable of in the given movement.
    ---@return number The deceleration
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

    function s:Forced(on)
        s.forced = on
    end

    function s:BrakeFlush()
        -- The brake vector must point against the direction of travel.
        local brakeVector = finalDeceleration()
        unit.setEngineCommand("brake", { brakeVector:Unpack() }, { 0, 0, 0 }, true, true, "", "", "", 0.001)
    end

    function s:GravityInfluencedAvailableDeceleration()
        local dot = GravityDirection():Dot(Velocity():Normalize())
        local movingTowardsGravityWell = dot > 0
        local influence = calc.Ternary(movingTowardsGravityWell, -1, 1)
        -- Might not be enough brakes to counter gravity so don't go below 0
        return max(0, rawAvailableDeceleration() + influence * dot * G())
    end

    function s:AvailableDeceleration()
        return rawAvailableDeceleration()
    end

    ---@param targetSpeed number The desired speed
    ---@param currentSpeed number The current speed
    ---@return Vec3 The thrust needed to counter the thrust induced by the braking operation
    function s:Feed(targetSpeed, currentSpeed)
        local diff = targetSpeed - currentSpeed
        pid:inject(-diff) -- Negate to make PID become positive when we have too high speed.

        local brakeValue = clamp(pid:get(), 0, 1)
        brakeData.pid = brakeValue

        deceleration = brakeValue * rawAvailableDeceleration()

        return brakeCounter()
    end

    instance = setmetatable(s, Brake)
    return instance
end

return Brake
