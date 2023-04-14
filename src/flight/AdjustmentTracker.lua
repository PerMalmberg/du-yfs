local PID = require("cpml/pid")
local Sign = require("util/Calc").Sign

---@class AdjustmentTracker
---@field TrackDistance fun(new:number):number
---@field Feed fun(distance:number):number
---@field ResetPID fun()

local AdjustmentTracker = {}
AdjustmentTracker.__index = AdjustmentTracker

---@return AdjustmentTracker
function AdjustmentTracker.New()
    local s = {}
    local pid = PID(0.01, 0.1, 5, 0.5)
    local lastDistance = 0

    ---@param new number
    ---@return number
    function s.TrackDistance(new)
        local sign   = Sign(new - lastDistance)
        lastDistance = new

        return sign
    end

    ---@param distance number
    ---@return number
    function s.Feed(distance)
        pid:inject(distance)
        return pid:get()
    end

    function s.ResetPID()
        pid:reset()
    end

    return setmetatable(s, AdjustmentTracker)
end

return AdjustmentTracker
