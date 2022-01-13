local library = require("abstraction/Library")()
local json = require("builtin/dkjson")
local utils = require("builtin/cpml/utils")
local vec3 = require("builtin/cpml/vec3")
local Constants = require("Constants")
local clamp = utils.clamp
local jdecode = json.decode
local round = utils.round

local brakes = {}
brakes.__index = brakes

local singelton = nil

local minimumSpeedForMaxAtmoBrakeForce = 100 --m/s (360km/h) Minimum speed in atmo to reach maximum brake force

local function new()
    local core = library.GetCoreUnit()
    local ctrl = library.GetController()

    local instance = {
        GetData = ctrl.getData,
        AtmoDensity = ctrl.getAtmosphereDensity,
        G = core.g,
        lastUpdateAtmoDensity = nil,
        lastUpdateG = 0,
        currentAtmoForce = 0,
        currentSpaceForce = 0,
        Speed = function()
            return vec3(core.getWorldAbsoluteVelocity()):len()
        end
    }

    setmetatable(instance, brakes)

    instance.updateHandler = system:onEvent("update", instance.Update, instance)

    return instance
end

function brakes:calculateBreakForce()
    --[[
        The effective brake force in atmo depends on the atmosphere density and current speed.
        - Speed affects break force such that it increases from 10% to 100% at <=10m/s to >=100m/s
        - Atmospheric density affects break force in a linearly.
    ]]
    local gNow = round(self.G(), 5) -- g changes frequently so avoid frequent updates.
    local atmoNow = self.AtmoDensity()

    if self.lastUpdateAtmoDensity == nil or (atmoNow ~= self.lastUpdateAtmoDensity or gNow ~= self.lastUpdateG) then
        self.lastUpdateAtmoDensity = atmoNow
        self.lastUpdateG = gNow

        local force = jdecode(self.GetData()).maxBrake

        if force ~= nil and force > 0 then
            if self.AtmoDensity() > Constants.atmoToSpaceDensityLimit then
                local speedAdjustment = clamp(self.Speed() / minimumSpeedForMaxAtmoBrakeForce, 0.1, 1)
                self.currentAtmoForce = force * speedAdjustment * self.AtmoDensity()
            else
                self.currentSpaceForce = force
            end
        end
    end
end

function brakes:MaxAtmoForce()
    return self.currentAtmoForce
end

function brakes:MaxSpaceForce()
    return self.currentSpaceForce
end

function brakes:Update()
    self:calculateBreakForce()
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
