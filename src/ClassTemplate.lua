local X = {}
X.__index = X

local function new(a, b, c)
    local instance = {}

    setmetatable(instance, X)

    return instance
end

-- The module
return setmetatable({ new = new }, { __call = function(_, ...)
    return new(...)
end })

--[[
local ClassName = {}
ClassName.__index = ClassName
function ClassName:new(args)
    local self = {}
    -- Public field
    self.field = nil

    -- Private attribute
    local attribute = nil

    -- Metafunction
    function self:__add(o1, o2)
    end

    -- Private function
    local function privateFunction()
    end

    -- Public function
    function self:publicFunction()
    end

    return setmetatable(self, ClassName)
end

-- Static function
ClassName.staticFunction()

return ClassName

]]--