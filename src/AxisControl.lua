local library = require("abstraction/Library")()
local ValueWidget = require("Panel/ValueWidget")

local control = {}
control.__index = control

---Creates a new AxisControl
---@param maxAcceleration number radians/s2
---@return table A new AxisControl
local function new(maxAcceleration)
    local core = library.GetCoreUnit()

    local instance = {
        core = core,
        maxAcc = maxAcceleration
    }

    setmetatable(instance, control)
    return instance
end

function control:SetTarget(targetCoordinate)
    
end

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
