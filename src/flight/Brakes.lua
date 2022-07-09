local EngineGroup = require("du-libs:abstraction/EngineGroup")
local Stopwatch = require("du-libs:system/Stopwatch")
local library = require("du-libs:abstraction/Library")()
local vehicle = require("du-libs:abstraction/Vehicle")()
local checks = require("du-libs:debug/Checks")
local calc = require("du-libs:util/Calc")
local sharedPanel = require("du-libs:panel/SharedPanel")()
local clamp = require("cpml/utils").clamp
local universe = require("du-libs:universe/Universe")()
local abs = math.abs
local max = math.max

local brakes = {}
brakes.__index = brakes

local singelton = nil
local world = vehicle.world
local mass = vehicle.mass
local velocity = vehicle.velocity

local minimumSpeedForMaxAtmoBrakeForce = 100 --m/s (360km/h) Minimum speed in atmo to reach maximum brake force
local brakeEfficiencyFactor = 0.6 -- Assume brakes are this efficient
local engineWarmupTime = 3

local function new()
    local ctrl = library:GetController()

    local instance = {
        ctrl = ctrl,
        engaged = false,
        forced = false,
        updateTimer = Stopwatch(),
        currentForce = 0,
        totalMass = 1,
        isWithinAtmo = true,
        brakeGroup = EngineGroup("brake"),
        wEngaged = sharedPanel:Get("Brakes"):CreateValue("Engaged", ""),
        wDistance = sharedPanel:Get("Brakes"):CreateValue("Brake dist.", "m"),
        wNeeded = sharedPanel:Get("Brakes"):CreateValue("Needed acc.", "m/s2"),
        wDeceleration = sharedPanel:Get("Brakes"):CreateValue("Deceleration", "m/s2"),
        wGravInfluence = sharedPanel:Get("Brakes"):CreateValue("Grav. Influence", "m/s2"),
        wBrakeAcc = sharedPanel:Get("Brakes"):CreateValue("Brake Acc.", "m/s2"),
        wMaxBrake = sharedPanel:Get("Brakes"):CreateValue("Max .", "kN"),
        wAtmoDensity = sharedPanel:Get("Brakes"):CreateValue("Atmo. den.", ""),
        wWithinAtmo = sharedPanel:Get("Brakes"):CreateValue("Within atmo", "")
    }

    setmetatable(instance, brakes)

    -- Do this at start to get some initial values
    instance:calculateBreakForce(true)
    instance.updateTimer:Start()

    return instance
end

function brakes:BrakeUpdate()
    local pos = vehicle.position.Current()
    self.isWithinAtmo = universe:ClosestBody(pos):IsWithinAtmosphere(pos)
    self:calculateBreakForce()
    self.wWithinAtmo:Set(self.isWithinAtmo)
    self.wEngaged:Set(self:IsEngaged())
    self.wDistance:Set(calc.Round(self:BrakeDistance(), 1))
    self.wDeceleration:Set(calc.Round(self:Deceleration(), 2))
end

function brakes:IsEngaged()
    return self.enabled or self.forced
end

function brakes:Set(on)
    self.enabled = on
end

function brakes:Forced(on)
    self.forced = on
end

function brakes:BrakeFlush()
    -- The brake vector must point against the direction of travel.
    if self:IsEngaged() then
        local brakeVector = -velocity.Movement():normalize() * self:Deceleration()
        self.ctrl.setEngineCommand(self.brakeGroup:Intersection(), { brakeVector:unpack() }, 1, 1, "", "", "", 0.001)
    else
        self.ctrl.setEngineCommand(self.brakeGroup:Intersection(), { 0, 0, 0 }, 1, 1, "", "", "", 0.001)
    end
end

function brakes:calculateBreakForce(forcedUpdate)
    --[[
        The effective brake force in atmo depends on the atmosphere density and current speed.
        - Speed affects break force such that it increases from 10% to 100% at >=10m/s to >=100m/s
        - Atmospheric density affects break force in a linearly.
    ]]

    if forcedUpdate or self.updateTimer:Elapsed() > 0.1 then
        local density = world.AtmoDensity()
        self.wAtmoDensity:Set(calc.Round(density, 5))
        self.updateTimer:Start()

        self.totalMass = mass.Total()

        local force = construct.getMaxBrake()
        local speed = velocity.Movement():len()

        if force ~= nil and force > 0 then
            if self.isWithinAtmo then
                local speedAdjustment = clamp(speed / minimumSpeedForMaxAtmoBrakeForce, 0.1, 1)
                force = force * speedAdjustment * density
            end

            self.currentForce = force
        end

        self.wMaxBrake:Set(calc.Round(self.currentForce / 1000, 1))
    end
end

---Returns the deceleration the construct is capable of in the given movement.
---@return number The deceleration
function brakes:Deceleration()
    -- F = m * a => a = F / m
    return self.currentForce / self.totalMass
end

function brakes:GravityInfluence(velocity)
    checks.IsVec3(velocity, "velocity", "bakes:GravityInfluence")

    -- When gravity is present, it reduces the available brake force in directions towards the planet and increases it when going out from the planet.
    -- Determine how much the gravity affects us by checking the alignment between our movement vector and the gravity.
    local gravity = world.G()

    local influence = 0

    if gravity > 0 then
        local velNorm = velocity:normalize()
        local vertRef = universe:VerticalReferenceVector()
        local dot = vertRef:dot(velNorm)

        if dot > 0 then
            -- Traveling in the same direction - we're influenced such that the break force is reduced
            local gAlongRef = gravity * vertRef
            influence = -(gAlongRef * velNorm):len() -- -gravity:project_on(velocity):len()
        end
        --[[elseif dot < 0 then
                -- Traveling against gravity - break force is increased
                influence = gravity:project_on(velocity):len()
            end]]
    end

    self.wGravInfluence:Set(calc.Round(influence, 1))
    return influence
end

function brakes:BrakeDistance(remainingDistance)
    -- https://www.khanacademy.org/science/physics/one-dimensional-motion/kinematic-formulas/a/what-are-the-kinematic-formulas
    -- distance = (v^2 - V0^2) / 2*a

    local calcBrakeDistance = function(speed, acceleration)
        return (speed ^ 2) / (2 * acceleration)
    end

    local calcAcceleration = function(speed, distance)
        return (speed ^ 2) / (2 * distance)
    end

    remainingDistance = remainingDistance or 0

    local vel = velocity.Movement()
    local speed = vel:len()

    local deceleration = self:Deceleration()

    if self.isWithinAtmo then
        -- Assume we only have a fraction of the brake force available
        deceleration = deceleration * brakeEfficiencyFactor
    end

    local distance = 0
    local accelerationNeededToBrake = 0

    if self.currentForce > 0 then
        local influence = abs(self:GravityInfluence(vel))
        deceleration = max(deceleration + influence, 0)

        local warmupDistance = engineWarmupTime * speed
        distance = calcBrakeDistance(speed, deceleration) + warmupDistance

        if vel:len() > calc.Kph2Mps(3) and distance >= remainingDistance and remainingDistance > 0 then
            -- Not enough brake force with just the brakes
            accelerationNeededToBrake = calcAcceleration(speed, remainingDistance)
        end
    end

    self.wBrakeAcc:Set(calc.Round(deceleration, 1))
    self.wNeeded:Set(calc.Round(accelerationNeededToBrake, 1))

    return distance, accelerationNeededToBrake
end

return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                if singelton == nil then
                    singelton = new()
                end
                return singelton
            end
        }
)