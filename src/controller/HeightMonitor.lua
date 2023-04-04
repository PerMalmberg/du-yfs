---@class HeightMonitor
---@field Track fun(height:number)
---@field Enable fun()
---@field IsTracking fun():boolean

local HeightMonitor = {}
HeightMonitor.__index = HeightMonitor

function HeightMonitor.New()
    local s = {}

    local last = {} ---@type number[]
    local enabled = false

    function s.Enable()
        last = {}
        enabled = true
    end

    function s.IsTracking()
        return enabled
    end

    ---Feeds the monitor, returns true when the direction changes and also disables the tracker
    ---@param value number
    ---@return boolean
    function s.Track(value)
        if not enabled then
            return false
        end

        while #last >= 3 do
            table.remove(last, 1)
        end

        last[#last + 1] = value

        local changed = false
        if #last == 3 then
            local first, second, third = last[1], last[2], last[3]
            -- Increasing, decreasing?
            if first ~= second then
                if second == third then
                    -- Flattened out
                    changed = true
                else
                    local increasing = first < second

                    changed = (third > second) ~= increasing
                end
            else
                table.remove(last, 1)
            end
        end

        enabled = not changed

        return changed
    end

    return setmetatable(s, HeightMonitor)
end

return HeightMonitor
