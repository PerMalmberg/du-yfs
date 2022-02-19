local X = {}
X.__index = X

local function new(a, b, c)
    local instance = {}

    setmetatable(instance, X)

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
