local engineGroup = {}
engineGroup.__index = engineGroup

local function new(name)
    local e = {
        tags = {},
        dirty = true,
        union = ""
    }
    local t = setmetatable(e, engineGroup)

    if name ~= nil then
        t:Add(name)
    end

    return t
end

function engineGroup:Add(name --[[string]])
    -- Append at the end of the list
    table.insert(self.tags, #self.tags + 1, name)
    self.dirty = true
end

function engineGroup:Union()
    if self.dirty then
        self.union = table.concat(self.tags, ",")
        self.dirty = false
    end

    return self.union
end

-- the module
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
