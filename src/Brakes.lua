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

local brakes = {}
brakes.__index = brakes

local singelton = nil
local world = construct.world
local mass = construct.mass
local velocity = construct.velocity

local minimumSpeedForMaxAtmoBrakeForce = 100 --m/s (360km/h) Minimum speed in atmo to reach maximum brake force

local function new()
    local ctrl = library.GetController()

    local instance = {
        ctrl = ctrl,
        percentage = 0,
        GetData = ctrl.getData,
        lastUpdateAtmoDensity = nil,
        currentAtmoForce = 0,
        currentSpaceForce = 0,
        totalMass = 1,
        brakeParts = {},
        brakeGroup = EngineGroup("brake"),
        wPercentage = sharedPanel:Get("Breaks"):CreateValue("Percentage", "%"),
        wDistance = sharedPanel:Get("Breaks"):CreateValue("Brake dist.", "m"),
        wDeceleration = sharedPanel:Get("Breaks"):CreateValue("Deceleration", "m/s2"),
        wGravInfluence = sharedPanel:Get("Breaks"):CreateValue("Grav. Influence", "m/s2"),
        wBrakeAcc = sharedPanel:Get("Breaks"):CreateValue("Brake Acc.", "m/s2")
    }

    setmetatable(instance, brakes)

    -- Do this at start to get some initial values
    instance:calculateBreakForce()

    return instance
end

function brakes:Update()
    self:calculateBreakForce()
    self.wPercentage:Set(self.percentage)
    self.wDistance:Set(calc.Round(self:BrakeDistance(), 2))
    self.wDeceleration:Set(calc.Round(self:Deceleration(), 2))
end

function brakes:Flush()
    -- The brake vector must point against the direction of travel.
    local brakeVector = vec3()

    for _, dir in pairs(self.brakeParts) do
        brakeVector = brakeVector + dir
    end

    brakeVector = brakeVector:normalize_inplace() * self:Deceleration()

    brakeVector = brakeVector - velocity.Movement():normalize() * self:Deceleration() * self.percentage

    self.ctrl.setEngineCommand(self.brakeGroup:Union(), {brakeVector:unpack()})
end

function brakes:Set(percentage)
    self.percentage = percentage or 100
end

function brakes:SetPart(partName, direction)
    self.brakeParts[partName] = direction
end

function brakes:calculateBreakForce()
    --[[
        The effective brake force in atmo depends on the atmosphere density and current speed.
        - Speed affects break force such that it increases from 10% to 100% at <=10m/s to >=100m/s
        - Atmospheric density affects break force in a linearly.
    ]]
    local density = world.AtmoDensity()
    local atmoNow = calc.Round(density, 5) -- Reduce noise to reduce how often we have to recalculate

    if self.lastUpdateAtmoDensity == nil or atmoNow ~= self.lastUpdateAtmoDensity then
        self.lastUpdateAtmoDensity = atmoNow

        self.totalMass = mass.Total()

        local force = jdecode(self.GetData()).maxBrake
        local speed = velocity.Movement():len()

        if force ~= nil and force > 0 then
            if world.IsInAtmo() then
                local speedAdjustment = clamp(speed / minimumSpeedForMaxAtmoBrakeForce, 0.1, 1)
                self.currentAtmoForce = force * speedAdjustment * density
            else
                self.currentSpaceForce = force
            end
        end
    end
end

---Returns the deceleration the constuct is capable of in the given movement.
---@return number The deceleration
function brakes:Deceleration()
    -- F = m * a
    if world.IsInAtmo() then
        return self.currentAtmoForce / self.totalMass
    else
        return self.currentSpaceForce / self.totalMass
    end
end

function brakes:GravityInfluence(velocity)
    diag:AssertIsVec3(velocity, "velocity", "bakes:GravityInfluence")

    -- When gravity is present, it reduces the available brake force in directions towards the planet and increases it when going out from the planet.
    -- Determine how much the gravity affects us by checking the alignment between our movement vector and the gravity.
    local gravity = world.GAlongGravity()

    local gravity2 = gravity:len2()
    local influence = 0

    if gravity2 > 0 then
        local dot = gravity:dot(velocity)

        if dot > 0 then
            -- Traveling in the same direction - we're infuenced such that the break force is reduced
            influence = -gravity:project_on(velocity):len()
        elseif dot < 0 then
            -- Traveling against gravity - break force is increased
            influence = gravity:project_on(velocity):len()
        end
    end

    self.wGravInfluence:Set(calc.Round(influence, 4))
    return influence
end

function brakes:BrakeDistance()
    -- https://www.khanacademy.org/science/physics/one-dimensional-motion/kinematic-formulas/a/what-are-the-kinematic-formulas
    -- distance = (v^2 - V0^2) / 2*a

    local vel = velocity.Movement()
    local brakeAcceleration = self:Deceleration() + self:GravityInfluence(vel)

    self.wBrakeAcc:Set(calc.Round(brakeAcceleration, 4))

    local V0 = vel:len()

    -- If gravity is larger than the brake acceleration then we return a realy long brake distance.
    if brakeAcceleration <= 0 then
        return 9999999
    else
        return (V0 * V0) / (2 * brakeAcceleration)
    end
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
