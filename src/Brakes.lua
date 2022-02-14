local library = require("abstraction/Library")()
local json = require("builtin/dkjson")
local utils = require("builtin/cpml/utils")
local construct = require("abstraction/Construct")()
local sharedPanel = require("panel/SharedPanel")()
local EngineGroup = require("EngineGroup")
local calc = require("Calc")
local vec3 = require("builtin/cpml/vec3")
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
        brakeGroup = EngineGroup("brake"),
        wDistance = sharedPanel:Get("Breaks"):CreateValue("Dist.", "m"),
        wDeceleration = sharedPanel:Get("Breaks"):CreateValue("Deceleration.", "m/s2")
    }

    setmetatable(instance, brakes)

    -- Do this at start to get some initial values
    instance:calculateBreakForce()

    return instance
end

function brakes:Update()
    self:calculateBreakForce()
    self.wDistance:Set(calc.Round(self:BreakDistance(), 2))
    self.wDeceleration:Set(calc.Round(self:Deceleration(), 2))
end

function brakes:Flush()
    -- The brake vector must point against the direction of travel, so negate it.
    local brakeVector = -velocity.Movement():normalize() * self:Deceleration() * self.percentage
    self.ctrl.setEngineCommand(self.brakeGroup:Union(), {brakeVector:unpack()})
end

function brakes:Set(percentage)
    self.percentage = percentage or 100
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

function brakes:BreakDistance()
    -- https://www.khanacademy.org/science/physics/one-dimensional-motion/kinematic-formulas/a/what-are-the-kinematic-formulas
    -- distance = (v^2 - V0^2) / 2*a
    -- Resulting force, gravity -

    local V0 = velocity.Movement():len()
    local a = self:Deceleration()

    -- When gravity is present, it reduces the available brake force in directions towards the planet and increases it when going out from the planet.
    -- Determine how much the gravity affects us by checking the alignment between our movement vector and the gravity.
    local gravity = world.GAlongGravity()

    if gravity:len2() > 0 then
        local travelDir = velocity.Movement():normalize()
        local absGrav = abs(gravity:len())
        local dot = travelDir:dot(gravity)

        a = a - dot * absGrav

    --[[if dot > 0 then
            -- Traveling in the same direction - we're infuenced such that the break force is reduced
            a = a - abs(dot) * absGrav:len()
        elseif dot < 0 then
            -- Traveling against gravity - break force is increased
            a = a + abs(dot) * absGrav:len()
        end]]
    end

    return (V0 * V0) / (2 * a)
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
