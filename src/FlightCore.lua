---@diagnostic disable: undefined-doc-name

local vec3 = require("builtin/vec3")
local EngineGroup = require("EngineGroup")
local Stabilizer = require("Stabilizer")

local flightCore = {}
flightCore.__index = flightCore

local function new(controller)
    local instance = {
        Core = library.getCoreUnit(),
        Ctrl = controller,
        desiredDirection = vec3(),
        desiredAccelerationX = 0,
        desiredAccelerationY = 0,
        desiredAccelerationZ = 0,
        desiredAngularAccelerationX = 0,
        desiredAngularAccelerationY = 0,
        desiredAngularAccelerationZ = 0,
        accelerationGroup = EngineGroup("ALL"),
        rotationGroup = EngineGroup("torque"),
        eventHandlerId = 0,
        dirty = false,
        stabilizer = nil
    }

    instance.stabilizer = Stabilizer(library.getCoreUnit(), controller, instance)
    setmetatable(instance, flightCore)

    return instance
end

function flightCore:GetStabilizer()
    return self.stabilizer
end

---@param group EngineGroup The engine group to apply the acceleration to
---@param direction vec3 direction we want to travel with the given acceleration
---@param acceleration number m/s2
function flightCore:SetAcceleration(group, direction, acceleration)
    self.accelerationGroup = group
    local acc = direction * acceleration
    self.desiredAccelerationX, self.desiredAccelerationY, self.desiredAccelerationZ = acc:unpack()
    self.dirty = true
end

---@param group EngineGroup The engine group to apply the rotation to
---@param rotation vec3 the desired angular rotational acceleration expressed in world coordinates and rad/s2
function flightCore:SetRotation(rotation)
    self.desiredAngularAccelerationX, self.desiredAngularAccelerationY, self.desiredAngularAccelerationZ =
        rotation:unpack()

    self.dirty = true
end

function flightCore:GetDesiredAcceleration()
    return vec3(self.desiredAccelerationX, self.desiredAccelerationY, self.desiredAccelerationZ)
end

function flightCore:ReceiveEvents()
    self.eventHandlerId = system:onEvent("flush", self.Flush, self)
end

function flightCore:StopEvents()
    self:clearEvent("flush", self.eventHandlerId)
end

function flightCore:EnableStabilization()
    self.stabilizer:Enable()
end

function flightCore:DisableStabilization()
    self.stabilizer:Disable()
end

function flightCore:Flush()
    self.stabilizer:Stabilize()

    if self.dirty and self.Ctrl ~= nil then
        self.dirty = false
        self.Ctrl.setEngineCommand(
            self.accelerationGroup:Union(),
            {
                self.desiredAccelerationX,
                self.desiredAccelerationY,
                self.desiredAccelerationZ
            }
        )

        self.Ctrl.setEngineCommand(
            self.rotationGroup:Union(),
            {
                0,
                0,
                0
            },
            {
                self.desiredAngularAccelerationX,
                self.desiredAngularAccelerationY,
                self.desiredAngularAccelerationZ
            }
        )
    end
end

-- The module
return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            return new(...)
        end
    }
)
