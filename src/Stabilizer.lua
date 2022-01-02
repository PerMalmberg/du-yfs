local vec3 = require("builtin/vec3")
local Pid = require("builtin/pid")

local stab = {}
stab.__index = stab

---Creates a new Stabilizer that alignes the construct to a reference direction
---@param core Core The core
---@param flightcore The FlightCore
---@return table The new Stabilizer
local function new(core, flightcore)
    local instance = {
        core = core,
        flightCore = flightcore,
        enabled = false,
        pidX = Pid(0, 0.01, 100),
        pidY = Pid(0, 0.01, 100),
        pidZ = Pid(0, 0.01, 100),
        baseAngularRotation = 2 * math.pi, -- One turn per second.
        -- Shall return the reference vector and vector to adjust towards reference.
        getVectors = nil
    }

    setmetatable(instance, stab)
    return instance
end


function stab:Enable()
    self.enabled = true
end

function stab:Disable()
    self.enabled = false
end


function stab:StablilizeUpward()
    self.getVectors = function()
        local core = self.core
        return -vec3(core.getWorldVertical()), vec3(core.getConstructWorldUp())
    end

    self:Enable()
end

---Stabilizes the construct based on the two vectors returned by the getVectors member function
function stab:Stabilize()
    if self.enabled and self.getVectors ~= nil then
        local ref, toAdjust = self:getVectors()

        local cross = toAdjust:cross(ref)

        self.pidX:inject(cross.x)
        self.pidY:inject(cross.y)
        self.pidZ:inject(cross.z)

        local angularSpeed = vec3(self.pidX:get(), self.pidY:get(), self.pidZ:get())
        angularSpeed = angularSpeed * self.baseAngularRotation
        self.flightCore:SetRotation(angularSpeed)
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
