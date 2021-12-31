local vec3 = require("builtin/vec3")

local stab = {}
stab.__index = stab

local function new(core, flightcore)
    local instance = {
        core = core,
        flightCore = flightcore,
        enabled = false
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

        self.flightCore:SetRotation(cross)
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
