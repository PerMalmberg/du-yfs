local library = require("abstraction/Library")()
local ValueWidget = require("Panel/ValueWidget")

local panel = {}
panel.__index = panel

local function new(title)
    local core = library.GetCoreUnit()

    local instance = {
        core = core,
        title = title,
        panelId = system.createWidgetPanel(title),
        widgets = {}
    }

    setmetatable(instance, panel)
    return instance
end

function panel:Close()
    for _, widget in ipairs(self.widgets) do
        widget:Close()
    end

    system.destroyWidgetPanel(self.panelId)
end

function panel:CreateValue(title, unit)
    local w = ValueWidget(self.panelId, title, unit)
    self.widgets[w.widgetId] = w
    return w
end

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
