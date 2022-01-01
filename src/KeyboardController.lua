local keyboardController = {}
keyboardController.__index = keyboardController

local function new(controller)
    local instance = {
        core = library.getCoreUnit(),
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

    instance.stabilizer = Stabilizer(library.getCoreUnit(), instance)
    setmetatable(instance, flightCore)

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
