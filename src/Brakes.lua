local library = require("abstraction/Library")()
local json = require("dkjson")
local utils = require("cpml/utils")
local vec3 = require("cpml/vec3")
local diag = require("Diagnostics")()
local construct = require("abstraction/Construct")()
local sharedPanel = require("panel/SharedPanel")()
local EngineGroup = require("EngineGroup")
local calc = require("Calc")
local clamp = utils.clamp
local jdecode = json.decode
local abs = math.abs
local max = math.max

local brakes = {}
brakes.__index = brakes

local singelton = nil
local world = construct.world
local mass = construct.mass
local velocity = construct.velocity
local nullVec = vec3()

local minimumSpeedForMaxAtmoBrakeForce = 100 --m/s (360km/h) Minimum speed in atmo to reach maximum brake force
local brakeEfficiencyFactor = 0.3 -- Assume brakes are this efficient

local function new()
    local ctrl = library.GetController()

    local instance = {
        ctrl = ctrl,
        engaged = false,
        GetData = ctrl.getData,
        lastUpdateAtmoDensity = nil,
        currentAtmoForce = 0,
        currentSpaceForce = 0,
        totalMass = 1,
        brakeParts = {},
        brakeGroup = EngineGroup("brake"),
        wEnagaged = sharedPanel:Get("Brakes"):CreateValue("Engaged", ""),
        wDistance = sharedPanel:Get("Brakes"):CreateValue("Brake dist.", "m"),
        wDeceleration = sharedPanel:Get("Brakes"):CreateValue("Deceleration", "m/s2"),
        wGravInfluence = sharedPanel:Get("Brakes"):CreateValue("Grav. Influence", "m/s2"),
        wBrakeAcc = sharedPanel:Get("Brakes"):CreateValue("Brake Acc.", "m/s2"),
        wMaxBrake = sharedPanel:Get("Brakes"):CreateValue("Max .", "N"),
        wAtmoDensity = sharedPanel:Get("Brakes"):CreateValue("Atmo. den.", "")
    }

    setmetatable(instance, brakes)

    -- Do this at start to get some initial values
    instance:calculateBreakForce()

    return instance
end

function brakes:Update()
    self:calculateBreakForce()
    self.wEnagaged:Set(tostring(self.engaged))
    self.wDistance:Set(calc.Round(self:BrakeDistance(), 4))
    self.wDeceleration:Set(calc.Round(self:Deceleration(), 2))
end

function brakes:Flush()
    local brakeVector = nullVec
    self.engaged = false

    for _, part_enabled in pairs(self.brakeParts) do
        if part_enabled then
            -- The brake vector must point against the direction of travel.
            brakeVector = -velocity.Movement():normalize() * self:Deceleration()
            self.engaged = true
            break
        end
    end

    self.ctrl.setEngineCommand(self.brakeGroup:Union(), {brakeVector:unpack()})
end

function brakes:SetPart(partName, enabled)
    self.brakeParts[partName] = enabled
end

function brakes:calculateBreakForce()
    --[[
        The effective brake force in atmo depends on the atmosphere density and current speed.
        - Speed affects break force such that it increases from 10% to 100% at >=10m/s to >=100m/s
        - Atmospheric density affects break force in a linearly.
    ]]
    local density = world.AtmoDensity()
    local atmoNow = calc.Round(density, 5) -- Reduce noise to reduce how often we have to recalculate

    if self.lastUpdateAtmoDensity == nil or atmoNow ~= self.lastUpdateAtmoDensity then
        self.lastUpdateAtmoDensity = atmoNow
        self.wAtmoDensity:Set(atmoNow)

        self.totalMass = mass.Total()

        local force = jdecode(self.GetData()).maxBrake
        local speed = velocity.Movement():len()

        if force ~= nil and force > 0 then
            if world.IsInAtmo() then
                local speedAdjustment = clamp(speed / minimumSpeedForMaxAtmoBrakeForce, 0.1, 1)
                self.currentAtmoForce = force * speedAdjustment * density
                self.wMaxBrake:Set(self.currentAtmoForce)
            else
                self.currentSpaceForce = force
                self.wMaxBrake:Set(self.currentSpaceForce)
            end
        end
    end
end

---Returns the deceleration the constuct is capable of in the given movement.
---@return number The deceleration
function brakes:Deceleration()
    -- F = m * a => a = F / m
    return self:CurrentBrakeForce() / self.totalMass
end

function brakes:CurrentBrakeForce()
    if world.IsInAtmo() then
        return self.currentAtmoForce
    else
        return self.currentSpaceForce
    end
end

function brakes:GravityInfluence(velocity)
    diag:AssertIsVec3(velocity, "velocity", "bakes:GravityInfluence")

    -- When gravity is present, it reduces the available brake force in directions towards the planet and increases it when going out from the planet.
    -- Determine how much the gravity affects us by checking the alignment between our movement vector and the gravity.
    local gravity = world.GAlongGravity()

    local influence = 0

    if gravity:len2() > 0 then
        local dot = gravity:normalize():dot(velocity:normalize())

        if dot > 0 then
            -- Traveling in the same direction - we're infuenced such that the break force is reduced
            influence = -gravity:project_on(velocity):len()
        end
    --[[elseif dot < 0 then
            -- Traveling against gravity - break force is increased
            influence = gravity:project_on(velocity):len()
        end]]
    end

    self.wGravInfluence:Set(calc.Round(influence, 4))
    return influence
end

function brakes:BrakeDistance()
    -- https://www.khanacademy.org/science/physics/one-dimensional-motion/kinematic-formulas/a/what-are-the-kinematic-formulas
    -- distance = (v^2 - V0^2) / 2*a

    local calcBrakeDistance = function(speed, acceleration)
        return (speed ^ 2) / (2 * acceleration)
    end

    local velocity = velocity.Movement()
    local speed = velocity:len()
    local deceleration = self:Deceleration()
    local influence = self:GravityInfluence(velocity)
    local total = deceleration + influence

    local distance = 0
    local accelerationNeededToBrake = 0

    if total > 0 then
        distance = calcBrakeDistance(speed, total)
    else
        distance = calcBrakeDistance(speed, deceleration)
        accelerationNeededToBrake = abs(influence)
    end

    if construct.world.IsInAtmo() then
        -- Assume we only have a fraction of the available brake force by doubling the distance.
        -- We do this since there are variables in play we don't understand.
        distance = distance / brakeEfficiencyFactor
        accelerationNeededToBrake = accelerationNeededToBrake / brakeEfficiencyFactor
    end

    self.wBrakeAcc:Set(calc.Round(total, 4))
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
