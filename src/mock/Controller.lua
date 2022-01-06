local controller = {}
controller.__index = controller

local function new()
    return setmetatable({}, controller)
end

function controller.setEngineCommand(tags, acceleration, angularAcceleration)
    io.write("SetEngineCommand: Tags: " .. tostring(tags) .. " acc:" .. tostring(acceleration) .. tostring(angularAcceleration))
end

function controller.getClosestPlanetInfluence()
    return 1 -- On ground
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
