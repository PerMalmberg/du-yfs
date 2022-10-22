local EngineGroup = require("abstraction/EngineGroup")
local vehicle = require("abstraction/Vehicle"):New()
local calc = require("util/Calc")
local sharedPanel = require("panel/SharedPanel")()
local universe = require("universe/Universe").Instance()
local nullVec = require("cpml/vec3")()
local PID = require("cpml/pid")
local IsInAtmo = vehicle.world.IsInAtmo
local TotalMass = vehicle.mass.Total
local Velocity = vehicle.velocity.Movement
local GravityDirection = vehicle.world.GravityDirection
local G = vehicle.world.G
local utils = require("cpml/utils")
local clamp = utils.clamp
local max = math.max

local Brake = {}
Brake.__index = Brake

local instance

function Brake:Instance()
    if instance then
        return instance
    end

    local p = sharedPanel:Get("Brakes")
    local pid = PID(1, 0, 0.01)
    local deceleration = 0
    local wDeceleration = p:CreateValue("Max deceleration", "m/s2")
    local wCurrentDec = p:CreateValue("Brake dec.", "m/s2")
    local wMass = p:CreateValue("Mass", "T")
    local wPid = p:CreateValue("Pid")

    local s = {
        engaged = false,
        forced = false,
        totalMass = TotalMass(),
        brakeGroup = EngineGroup("brake"),
    }

    ---Returns the deceleration the construct is capable of in the given movement.
    ---@return number The deceleration
    local function rawAvailableDeceleration()
        -- F = m * a => a = F / m
        return construct.getMaxBrake() / s.totalMass
    end

    local function finalDeceleration()
        if s.forced then
            return -Velocity():normalize() * rawAvailableDeceleration()
        else
            return -Velocity():normalize() * deceleration
        end
    end

    function s:BrakeUpdate()
        s.totalMass = TotalMass()
        wDeceleration:Set(calc.Round(rawAvailableDeceleration(), 2))
        wCurrentDec:Set(calc.Round(construct.getCurrentBrake() / s.totalMass, 2))
        wMass:Set(calc.Round(s.totalMass / 1000, 1))
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
            res = finalDeceleration():project_on(universe:VerticalReferenceVector())
        end

        return res
    end

    function s:Forced(on)
        s.forced = on
    end

    function s:BrakeFlush()
        -- The brake vector must point against the direction of travel.
        local brakeVector = finalDeceleration()
        unit.setEngineCommand(s.brakeGroup:Intersection(), { brakeVector:unpack() }, { 0, 0, 0 }, true, true,
            "", "", "", 0.001)
    end

    function s:GravityInfluencedAvailableDeceleration()
        local gravInfluence = (GravityDirection() * G()):dot(Velocity():normalize())
        -- Might not be enough brakes to counter gravity so don't go below 0
        return max(0, rawAvailableDeceleration() + gravInfluence)
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
        wPid:Set(calc.Round(brakeValue, 4))

        deceleration = brakeValue * rawAvailableDeceleration()

        return brakeCounter()
    end

    instance = setmetatable(s, Brake)
    return instance
end

return Brake
