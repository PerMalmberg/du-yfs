local FlightCore = require("FlightCore")
local diag = require("Diagnostics")()

local holdDirection = {}
holdDirection.__index = holdDirection

local function new(...)
    local instance = {
        fc = FlightCore(),
        targetCoordinate = nil
    }

    setmetatable(instance, holdDirection)

    return instance
end

function holdDirection:Hold(coordinate)
    diag:AssertIsVec3(coordinate, "coordinate in Hold must be a vec3")
    self.targetCoordinate = coordinate




end

return setmetatable(
    {
        new = new(...)
    },
    {
        __call = function(_, ...)
            return new(...)
        end
    }
)
