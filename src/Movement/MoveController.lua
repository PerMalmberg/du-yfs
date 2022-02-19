local diag = require("Diagnostics")

local mover = {}
mover.__index = mover

local function new(destination, alignTo, maxSpeed)
    diag:AssertIsVec3(destination, "destination", "MoveController:new")

    local instance = {
        destination = destination,
        alignTo = alignTo,
        maxSpeed = maxSpeed
    }

    setmetatable(instance, mover)

    return instance
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
