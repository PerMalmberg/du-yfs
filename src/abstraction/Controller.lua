local io = require("io")

local controller = {}
controller.__index = controller

local function new()
    return setmetatable({}, controller)
end

function controller:SetEngineCommand(tags, acceleration, angularAcceleration)
    io.write("SetEngineCommand: Tags: " .. tostring(tags) .. " acc:" .. tostring(acceleration) .. tostring(angularAcceleration))
end

-- the module
return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            return new()
        end
    }
)
