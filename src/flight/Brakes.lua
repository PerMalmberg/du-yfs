local EngineGroup = require("abstraction/EngineGroup")
local Stopwatch = require("system/Stopwatch")
local library = require("abstraction/Library")()
local vehicle = require("abstraction/Vehicle"):New()
local calc = require("util/Calc")
local sharedPanel = require("panel/SharedPanel")()
local universe = require("universe/Universe")()
local nullVec = require("cpml/vec3")()

local brakes = {}
brakes.__index = brakes

local TotalMass = vehicle.mass.Total
local Velocity = vehicle.velocity.Movement

local function new()
    local ctrl = library:GetController()
    local p = sharedPanel:Get("Brakes")

    local instance = {
        ctrl = ctrl,
        engaged = false,
        forced = false,
        totalMass = TotalMass(),
        isWithinAtmo = true,
        overrideAcc = nil,
        brakeGroup = EngineGroup("brake"),
        wDeceleration = p:CreateValue("Deceleration", "m/s2"),
        wWithinAtmo = p:CreateValue("Within atmo", ""),
        warmupTimer = Stopwatch()
    }

    setmetatable(instance, brakes)

    return instance
end

function brakes:BrakeUpdate()
    self.totalMass = TotalMass()
    local pos = vehicle.position.Current()
    self.isWithinAtmo = universe:ClosestBody(pos):IsWithinAtmosphere(pos)
    self.wWithinAtmo:Set(self.isWithinAtmo)
    self.wDeceleration:Set(calc.Round(self:Deceleration(), 2))
end

function brakes:IsEngaged()
    return self.enabled or self.forced
end

function brakes:Set(on, overrideAcc)
    self.enabled = on
    if on then
        self.overrideAcc = overrideAcc
    else
        self.overrideAcc = nil
    end
end

function brakes:Forced(on)
    self.forced = on
end

function brakes:FinalDeceleration()
    if not self:IsEngaged() then
        return nullVec
    end

    if self.forced then
        return -Velocity():normalize() * self:Deceleration()
    else
        return -Velocity():normalize() * (self.overrideAcc or self:Deceleration())
    end
end

function brakes:BrakeFlush()
    -- The brake vector must point against the direction of travel.
    if self:IsEngaged() then
        local brakeVector = self:FinalDeceleration()
        self.ctrl.setEngineCommand(self.brakeGroup:Intersection(), { brakeVector:unpack() }, 1, 1, "", "", "", 0.001)
    else
        self.ctrl.setEngineCommand(self.brakeGroup:Intersection(), { 0, 0, 0 }, 1, 1, "", "", "", 0.001)
    end
end

---Returns the deceleration the construct is capable of in the given movement.
---@return number The deceleration
function brakes:Deceleration()
    -- F = m * a => a = F / m
    return construct.getMaxBrake() / self.totalMass
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