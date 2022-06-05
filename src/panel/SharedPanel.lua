local Panel = require("panel/Panel")

local singleton = nil

local panel = {}
panel.__index = panel

local function new()
    local instance = {
        panels = {}
    }

    setmetatable(instance, panel)
    return instance
end

function panel:Close(title)
    local p = self.panels[title]
    if p ~= nil then
        p:Close()
        self.panels[title] = nil
    end
end

function panel:Get(title)
    if self.panels[title] == nil then
        self.panels[title] = Panel(title)
    end

    return self.panels[title]
end

return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                if singleton == nil then
                    singleton = new()
                end
                return singleton
            end
        }
)