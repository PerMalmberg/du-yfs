local AxisControl = require("flight/AxisControl")

---@class AxisManager
---@field Pitch fun():AxisControl
---@field Yaw fun():AxisControl
---@field Roll fun():AxisControl
---@field Flush fun()
---@field ReceiveEvents fun()
---@field StopEvents fun()
---@field SetYawTarget fun(target:Vec3?)
---@field SetPitchTarget fun(target:Vec3?)
---@field SetRollTarget fun(target:Vec3?)

local AxisManager = {}
AxisManager.__index = AxisManager
local instance ---@type AxisManager

---@return AxisManager
function AxisManager.Instance()
    if instance then return instance end

    local s = {}

    local pitch = AxisControl.New(ControlledAxis.Pitch)
    local roll = AxisControl.New(ControlledAxis.Roll)
    local yaw = AxisControl.New(ControlledAxis.Yaw)

    function s.ReceiveEvents()
        pitch.ReceiveEvents()
        roll.ReceiveEvents()
        yaw.ReceiveEvents()
    end

    function s.StopEvents()
        pitch.StopEvents()
        roll.StopEvents()
        yaw.StopEvents()
    end

    ---@param target Vec3?
    function s.SetYawTarget(target)
        if target then yaw.SetTarget(target) else yaw.Disable() end
    end

    ---@param target Vec3?
    function s.SetPitchTarget(target)
        if target then pitch.SetTarget(target) else pitch.Disable() end
    end

    ---@param target Vec3?
    function s.SetRollTarget(target)
        if target then roll.SetTarget(target) else roll.Disable() end
    end

    function s.Flush()
        pitch.AxisFlush(false)
        roll.AxisFlush(false)
        yaw.AxisFlush(true)
    end

    function s.Yaw() return yaw end

    function s.Pitch() return pitch end

    function s.Roll() return roll end

    instance = setmetatable(s, AxisManager)
    return instance
end

return AxisManager
