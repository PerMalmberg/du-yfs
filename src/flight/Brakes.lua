local EngineGroup = require("du-libs:abstraction/EngineGroup")
local Stopwatch = require("du-libs:system/Stopwatch")
local library = require("du-libs:abstraction/Library")()
local vehicle = require("du-libs:abstraction/Vehicle")()
local checks = require("du-libs:debug/Checks")
local calc = require("du-libs:util/Calc")
local sharedPanel = require("du-libs:panel/SharedPanel")()
local clamp = require("cpml/utils").clamp
local universe = require("du-libs:universe/Universe")()
local engine = require("du-libs:abstraction/Engine")()
local max = math.max

local brakes = {}
brakes.__index = brakes

local G = vehicle.world.G
local AtmoDensity = vehicle.world.AtmoDensity
local TotalMass = vehicle.mass.Total
local Velocity = vehicle.velocity.Movement

local minimumSpeedForMaxAtmoBrakeForce = 100 --m/s (360km/h) Minimum speed in atmo to reach maximum brake force
local brakeEfficiencyFactor = 0.6 -- Assume atmospheric brakes are this efficient
local engineWarmupTime = 1

local function new()
    local ctrl = library:GetController()
    local p = sharedPanel:Get("Brakes")

    local instance = {
        ctrl = ctrl,
        engaged = false,
        forced = false,
        updateTimer = Stopwatch(),
        currentForce = 0,
        totalMass = 1,
        isWithinAtmo = true,
        overrideAcc = nil,
        reason = "",
        brakeGroup = EngineGroup("brake"),
        wEngaged = p:CreateValue("Engaged", ""),
        wDistance = p:CreateValue("Brake dist.", "m"),
        wNeeded = p:CreateValue("Needed acc.", "m/s2"),
        wDeceleration = p:CreateValue("Deceleration", "m/s2"),
        wGravInfluence = p:CreateValue("Grav. Influence", "m/s2"),
        wBrakeAcc = p:CreateValue("Brake Acc.", "m/s2"),
        wMaxBrake = p:CreateValue("Max .", "kN"),
        wAtmoDensity = p:CreateValue("Atmo. den.", ""),
        wWithinAtmo = p:CreateValue("Within atmo", "")
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
    self.wEngaged:Set(self:GetReason())
    self.wDeceleration:Set(calc.Round(self:Deceleration(), 2))
end

function brakes:SetEngineWarmupTime(t)
    engineWarmupTime = t
end

function brakes:IsEngaged()
    return self.enabled or self.forced
end

function brakes:GetReason()
    return calc.Ternary(self.forced, "Forced", self.reason)
end

function brakes:Set(on, reason, overrideAcc)
    self.enabled = on
    if on then
        self.reason = reason
        self.overrideAcc = overrideAcc
    else
        self.reason = "-"
        self.overrideAcc = nil
    end
end

function brakes:Forced(on)
    self.forced = on
end

function brakes:BrakeFlush()
    -- The brake vector must point against the direction of travel.
    if self:IsEngaged() then
        local brakeVector = -Velocity():normalize() * (self.overrideAcc or self:Deceleration())
        self.ctrl.setEngineCommand(self.brakeGroup:Intersection(), { brakeVector:unpack() }, 1, 1, "", "", "", 0.001)
    else
        self.ctrl.setEngineCommand(self.brakeGroup:Intersection(), { 0, 0, 0 }, 1, 1, "", "", "", 0.001)
    end
end

function brakes:calculateBreakForce(forcedUpdate)
    --[[
        The effective brake force in atmo depends on the atmosphere density and current speed.
        - Speed affects break force such that it increases from 10% to 100% at >=10m/s to >=100m/s
        - Atmospheric density affects break force linearly.
    ]]

    if forcedUpdate or self.updateTimer:Elapsed() > 0.1 then
        local density = AtmoDensity()
        self.wAtmoDensity:Set(calc.Round(density, 5))
        self.updateTimer:Start()

        self.totalMass = TotalMass()

        local force = construct.getMaxBrake()
        local speed = Velocity():len()

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
    local gravity = G()

    local influence = 0

    if gravity > 0 then
        local velNorm = Velocity():normalize()
        local vertRef = universe:VerticalReferenceVector()
        local dot = vertRef:dot(velNorm)

        if dot > 0 then
            -- Traveling in the same direction - we're influenced such that the break force is reduced
            local gAlongRef = gravity * vertRef
            influence = -gAlongRef:dot(velNorm)
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

    local vel = Velocity()
    local speed = vel:len()

    local deceleration = self:Deceleration()

    if self.isWithinAtmo then
        -- Assume we only have a fraction of the brake force available
        deceleration = deceleration * brakeEfficiencyFactor
    end

    local distance = 0
    local engineAccelerationNeededToBrake = 0

    if self.currentForce > 0 then
        local influence = self:GravityInfluence(vel)

        local total = deceleration + influence
        local warmupDistance = engineWarmupTime * speed

        if total < 0 then
            -- Brakes do not have enough brake force to stop the construct
            local availableEngineAcc = engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(-vel:normalize())
            distance = calcBrakeDistance(speed, availableEngineAcc) + warmupDistance

            if remainingDistance > 0 and distance >= remainingDistance then
                engineAccelerationNeededToBrake = max(0, calcAcceleration(speed, remainingDistance) - deceleration)
            end
        else
            distance = calcBrakeDistance(speed, total)
            if remainingDistance > 0 and distance >= remainingDistance then
                engineAccelerationNeededToBrake = calcAcceleration(speed, remainingDistance)
            end
        end
    end

    self.wBrakeAcc:Set(calc.Round(deceleration, 1))
    self.wNeeded:Set(calc.Round(engineAccelerationNeededToBrake, 1))
    self.wDistance:Set(calc.Round(distance, 1))

    return distance, engineAccelerationNeededToBrake
end

local singleton
return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                if singleton == nil then
                    singleton = new()
                end
                return singleton
            end
        }
)