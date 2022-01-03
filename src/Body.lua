-- Body - stellar bodies

require("Asserts")

local body = {}
body.__index = body

local function new()
    local instance = {}
    setmetatable(instance, body)

    return instance
end

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
