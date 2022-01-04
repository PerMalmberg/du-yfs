local keyboardController = {}
keyboardController.__index = keyboardController

local function new(controller)
    local instance = {}


    setmetatable(instance, keyboardController)

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
