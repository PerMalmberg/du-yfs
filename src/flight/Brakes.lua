local EngineGroup = require("abstraction/EngineGroup")
local Stopwatch = require("system/Stopwatch")
local library = require("abstraction/Library")()
local vehicle = require("abstraction/Vehicle"):New()
local calc = require("util/Calc")
local sharedPanel = require("panel/SharedPanel")()
local clamp = require("cpml/utils").clamp
local universe = require("universe/Universe")()

local brakes = {}
brakes.__index = brakes

local G = vehicle.world.G
local TotalMass = vehicle.mass.Total
local Velocity = vehicle.velocity.Movement

local brakePeakSpeed = 100 -- The speed, at which brakes gives maximum brake force in m/s
local brakeEfficiencyFactor = 0.6 -- Assume atmospheric brakes are this efficient

local function new()
    local ctrl = library:GetController()
    local p = sharedPanel:Get("Brakes")

    local instance = {
        ctrl = ctrl,
        engaged = false,
        forced = false,
        updateTimer = Stopwatch(),
        totalMass = TotalMass(),
        isWithinAtmo = true,
        overrideAcc = nil,
        reason = "",
        state = "",
        engineWarmupTime = 1,
        brakeGroup = EngineGroup("brake"),
        wEngaged = p:CreateValue("Engaged", ""),
        wDistance = p:CreateValue("Brake dist.", "m"),
        wNeeded = p:CreateValue("Needed acc.", "m/s2"),
        wWarmupDist = p:CreateValue("Warm. dist.", "m"),
        wDeceleration = p:CreateValue("Deceleration", "m/s2"),
        wGravInfluence = p:CreateValue("Grav. Influence", "m/s2"),
        wBrakeAcc = p:CreateValue("Brake Acc.", "m/s2"),
        wMaxBrake = p:CreateValue("Max.", "kN"),
        wAtmoDensity = p:CreateValue("Atmo. den.", ""),
        wWithinAtmo = p:CreateValue("Within atmo", ""),
        warmupTimer = Stopwatch()
    }

    setmetatable(instance, brakes)

    -- Do this at start to get some initial values
    instance.updateTimer:Start()

    return instance
end

function brakes:BrakeUpdate()
    self.totalMass = TotalMass()
    local pos = vehicle.position.Current()
    self.isWithinAtmo = universe:ClosestBody(pos):IsWithinAtmosphere(pos)
    self.wWithinAtmo:Set(self.isWithinAtmo)
    self.wEngaged:Set(self:GetReason())
    self.wDeceleration:Set(calc.Round(self:Deceleration(), 2))
    self.wMaxBrake:Set(calc.Round(construct.getMaxBrake() / 1000, 1))
end

function brakes:SetEngineWarmupTime(t)
    self.engineWarmupTime = t * 2 -- Warmup time is to T50, so double it for full engine effect
end

function brakes:IsEngaged()
    return self.enabled or self.forced
end

function brakes:GetReason()
    return calc.Ternary(self.forced, "Forced", self.reason) .. " " .. self.state
end

function brakes:Set(on, reason, overrideAcc)
    self.enabled = on
    if on then
        self.reason = reason
        self.overrideAcc = overrideAcc
    else
        self.reason = "-"
        self.overrideAcc = nil
        self.state = ""
    end
end

function brakes:Forced(on)
    self.forced = on
end

function brakes:FinalDeceleration()
    return -Velocity():normalize() * (self.overrideAcc or self:Deceleration())
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

function brakes:GravityInfluence()

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

function brakes:GetWarmupDistance()
    local t = self.engineWarmupTime
    return clamp(t - self.warmupTimer:Elapsed(), 0, t) * Velocity():len()
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