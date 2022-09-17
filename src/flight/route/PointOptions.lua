
---@class PointOptions
---@field Set fun(self:table, name:string, value:any) Sets an option value
---@field Get fun(self:table, defaultValue:any): any a Gets an option value
---@field Data fun(self:table):table Gets the options as a table

local PointOptions = {}
PointOptions.__index = PointOptions

---Creates a new PointOptions instance
---@param optionData table An existing table holding option data or nil
---@return PointOptions
function PointOptions.New(optionData)
    local s = {
        options = optionData or {}
    }

    ---@param opt string The name of the option to set
    ---@param value any The value of the option
    function s:Set(opt, value)
        s.options[opt] = value
    end

    ---@param opt string The name of the option to get
    ---@param default any The default value if the option doesn't exist
    ---@return any # The option value, or the default value
    function s:Get(opt, default)
        return s.options[opt] or default
    end

    ---@return table # The options as a table
    function s:Data()
        return s.options
    end

    return setmetatable(s, PointOptions)
end

--- Unit vector in world coordinates in format {x,y,z}. Causes the direction of the construct to be locked to the direction stored in the point throughout the approach to the point.
PointOptions.LOCK_DIRECTION = "lockDir"
--- Boolean. Construct behaves as if it had wings, i.e. it will pitch/yaw/roll
PointOptions.USE_WINGS = "useWings" 
--- Meters. How close must the construct be to consider the point reached.
PointOptions.MARGIN = "margin"
--- m/s. Desired speed when the point is reached.
PointOptions.FINAL_SPEED = "finalSpeed"
--- m/s. Desired maximal speed. (equal or less than finalSpeed)
PointOptions.MAX_SPEED = "maxSpeed"
-- Boolean. If true, the approach to the point will be done using precision mode. Enable this for maneuvers like straight up/down travel
PointOptions.PRECISION = "precision"

return PointOptions