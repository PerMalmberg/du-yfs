local ClassName = {}
ClassName.__index = ClassName
function ClassName.New(args)
    local s = {}
    -- Public field
    s.Field = nil

    -- Private attribute
    local attribute = nil

    -- Meta function
    function s:__add(o1, o2)
    end

    -- Private function
    local function privateFunction()
    end

    -- Public function
    function s.PublicFunction()
    end

    return setmetatable(s, ClassName)
end

-- Static function
ClassName.StaticFunction = function()

end

return ClassName
