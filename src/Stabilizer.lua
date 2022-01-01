local vec3 = require("builtin/vec3")
local Pid = require("builtin/pid")

local stab = {}
stab.__index = stab

local function new(core, flightcore)
    local instance = {
        core = core,
        flightCore = flightcore,
        enabled = false,
        pidX = Pid(0, 0.01, 135.5),
        pidY = Pid(0, 0.01, 135.5),
        pidZ = Pid(0, 0.01, 135.5),
        baseAngularRotation = 2 * math.pi -- One turn per second.
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

function stab:Stabilize()
    if self.enabled then
        local worldUp = -vec3(self.core.getWorldVertical())
        local constructUp = vec3(self.core.getConstructWorldUp())
        local cross = constructUp:cross(worldUp)

        self.pidX:inject(cross.x)
        self.pidY:inject(cross.y)
        self.pidZ:inject(cross.z)

        local angularSpeed = vec3(self.pidX:get(), self.pidY:get(), self.pidZ:get())
        angularSpeed = angularSpeed * self.baseAngularRotation
        system.print(tostring(angularSpeed))
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
