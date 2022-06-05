local widget = {}
widget.__index = widget

local function new(panelId, title, unit)
    local instance = {
        panelId = panelId,
        title = title,
        unit = unit,
        widgetId = system.createWidget(panelId, "value"),
        dataId = nil,
        newValue = nil
    }

    setmetatable(instance, widget)
    return instance
end

function widget:Close()
    system.removeDataFromWidget(self.dataId, self.widgetId)
    system.destroyData(self.dataId)
    system.destroyWidget(self.widgetId)
end

function widget:Set(value)
    self.newValue = tostring(value)
end

function widget:Update()
    if self.newValue ~= nil then
        local s = '{ "label":"' .. self.title .. '", "value": "' .. self.newValue .. '", "unit": "' .. self.unit .. '"}'

        if self.dataId == nil then
            system.destroyData(self.dataId)
            self.dataId = system.createData(s)
            system.addDataToWidget(self.dataId, self.widgetId)
        else
            system.updateData(self.dataId, s)
        end

        self.newValue = nil
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