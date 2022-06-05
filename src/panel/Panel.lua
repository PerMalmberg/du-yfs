local ValueWidget = require("panel/ValueWidget")
local library = require("abstraction/Library")()

local panel = {}
panel.__index = panel

local function new(title)
    local instance = {
        core = library:GetCoreUnit(),
        title = title,
        panelId = system.createWidgetPanel(title),
        widgets = {},
        updateHandlerId = nil
    }

    setmetatable(instance, panel)

    instance.updateHandlerId = system:onEvent("update", instance.Update, instance)

    return instance
end

function panel:Close()
    system:clearEvent("update", self.updateHandlerId)

    for _, widget in pairs(self.widgets) do
        widget:Close()
    end

    system.destroyWidgetPanel(self.panelId)
end

function panel:CreateValue(title, unit)
    local w = ValueWidget(self.panelId, title, unit)
    self.widgets[w.widgetId] = w
    return w
end

function panel:Update()
    for _, widget in pairs(self.widgets) do
        widget:Update()
    end
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