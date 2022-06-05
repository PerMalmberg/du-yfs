local engineGroup = {}
engineGroup.__index = engineGroup

local function new(...)
    local e = {
        tags = {},
        dirty = true,
        intersection = ""
    }
    local t = setmetatable(e, engineGroup)

    for _, name in ipairs({ ... }) do
        if name ~= nil then
            t:Add(name)
        end
    end

    return t
end

---@param name string
function engineGroup:Add(name --[[string]])
    -- Append at the end of the list
    table.insert(self.tags, #self.tags + 1, name:lower())
    self.dirty = true
end

---@return string
function engineGroup:Intersection()
    if self.dirty then
        self.intersection = table.concat(self.tags, ",")
        self.dirty = false
    end

    return self.intersection
end

function engineGroup:__tostring()
    return self:Intersection()
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