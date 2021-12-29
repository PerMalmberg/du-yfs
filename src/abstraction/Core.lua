local core = {}
core.__index = core

local function new()
 return setmetatable(
        {            
        },
        core
    )
end

-- The module
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
