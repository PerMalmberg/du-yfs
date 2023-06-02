local PID = require("cpml/pid")

---@class AdjustmentTracker
---@field Feed fun(distance:number):number
---@field LastDistance fun():number
---@field ResetPID fun()

local AdjustmentTracker = {}
AdjustmentTracker.__index = AdjustmentTracker

---@param lightConstruct boolean True if the construct is light
---@return AdjustmentTracker
function AdjustmentTracker.New(lightConstruct)
    local s = {}
    local pid
    if lightConstruct then
        pid = PID(0.01, 0.1, 5, 0.5)
    else
        pid = PID(1, 0.5, 5, 0.5)
    end

    local lastDistance = 0

    ---@return number
    function s.LastDistance()
        return lastDistance
    end

    ---@param distance number
    ---@return number
    function s.Feed(distance)
        lastDistance = distance
        pid:inject(distance)
        return pid:get()
    end

    function s.ResetPID()
        pid:reset()
    end

    return setmetatable(s, AdjustmentTracker)
end

return AdjustmentTracker
