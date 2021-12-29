---@diagnostic disable: undefined-doc-name

local vec3 = require("builtin/vec3")
local EngineGroup = require("EngineGroup")

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
        group = EngineGroup("ALL"),
        eventHandlerId = 0
    }

    setmetatable(instance, flightCore)

    return instance
end

---@param group EngineGroup The engine group to apply the acceleration to
---@param direction vec3 direction we want to travel with the given acceleration
---@param acceleration number m/s2
function flightCore:SetAcceleration(group, direction, acceleration)
    self.group = group
    -- Ensure direction is a unit vector
    -- local acc = direction:normalize() * acceleration
    local acc = -vec3(self.Core.getWorldVertical()) * self.Core.g() * acceleration
    self.desiredAccelerationX, self.desiredAccelerationY, self.desiredAccelerationZ = acc:unpack()
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

function flightCore:Flush()
    if self.Ctrl ~= nil then
        self.Ctrl.setEngineCommand(
            self.group:Union(),
            {
                self.desiredAccelerationX,
                self.desiredAccelerationY,
                self.desiredAccelerationZ
            }
        )
    end
end

-- The module
return setmetatable(
    {
        new = new,
        RollAxle = vec3.unit_y,
        PitchAxle = vec3.unit_x,
        YawAxle = vec3.unit_z,
        Forward = vec3.unit_y,
        Right = vec3.unit_x,
        Up = vec3.unit_z
    },
    {
        __call = function(_, ...)
            return new(...)
        end
    }
)
