local EngineGroup = require("abstraction/EngineGroup")
local library = require("abstraction/Library")()
local vehicle = require("abstraction/Vehicle"):New()
local calc = require("util/Calc")
local sharedPanel = require("panel/SharedPanel")()
local universe = require("universe/Universe")()
local nullVec = require("cpml/vec3")()
local TotalMass = vehicle.mass.Total
local Velocity = vehicle.velocity.Movement

local Brake = {}
Brake.__index = Brake

local instance

function Brake:Instance()
    if instance then
        return instance
    end
    
    local ctrl = library:GetController()
    local p = sharedPanel:Get("Brakes")
    
    local s = {
        ctrl = ctrl,
        engaged = false,
        forced = false,
        totalMass = TotalMass(),
        isWithinAtmo = true,
        overrideAcc = nil,
        brakeGroup = EngineGroup("brake"),
        wDeceleration = p:CreateValue("Deceleration", "m/s2"),
        wWithinAtmo = p:CreateValue("Within atmo", ""),
    }

    function s:BrakeUpdate()
        s.totalMass = TotalMass()
        local pos = vehicle.position.Current()
        s.isWithinAtmo = universe:ClosestBody(pos):IsWithinAtmosphere(pos)
        s.wWithinAtmo:Set(s.isWithinAtmo)
        s.wDeceleration:Set(calc.Round(s:Deceleration(), 2))
    end

    function s:IsEngaged()
        return s.enabled or s.forced
    end

    function s:Set(on, overrideAcc)
        s.enabled = on
        if on then
            s.overrideAcc = overrideAcc
        else
            s.overrideAcc = nil
        end
    end

    function s:Forced(on)
        s.forced = on
    end

    function s:FinalDeceleration()
        if not s:IsEngaged() then
            return nullVec
        end

        if s.forced then
            return -Velocity():normalize() * s:Deceleration()
        else
            return -Velocity():normalize() * (s.overrideAcc or s:Deceleration())
        end
    end

    function s:BrakeFlush()
        -- The brake vector must point against the direction of travel.
        if s:IsEngaged() then
            local brakeVector = s:FinalDeceleration()
            s.ctrl.setEngineCommand(s.brakeGroup:Intersection(), { brakeVector:unpack() }, 1, 1, "", "", "", 0.001)
        else
            s.ctrl.setEngineCommand(s.brakeGroup:Intersection(), { 0, 0, 0 }, 1, 1, "", "", "", 0.001)
        end
    end

    ---Returns the deceleration the construct is capable of in the given movement.
    ---@return number The deceleration
    function s:Deceleration()
        -- F = m * a => a = F / m
        return construct.getMaxBrake() / s.totalMass
    end
    
    instance = setmetatable(s, Brake)
    return instance
end

return Brake