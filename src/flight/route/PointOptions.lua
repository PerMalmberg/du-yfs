---@class PointOptions
---@field New fun():PointOptions Creates a new PointOptions
---@field Set fun(name:string, value:any) Sets an option value
---@field Get fun(opt:string, defaultValue:any): any a Gets an option value
---@field Data fun():table<string, any> Gets the options as a table

local PointOptions = {}
PointOptions.__index = PointOptions

---Creates a new PointOptions instance
---@param optionData? table An existing table holding option data or nil
---@return PointOptions
function PointOptions.New(optionData)
    local s = {}
    local options = optionData or {}

    ---@param opt string The name of the option to set
    ---@param value string|number The value of the option
    function s.Set(opt, value)
        options[opt] = value
    end

    ---@param opt string The name of the option to get
    ---@param default string|number The default value if the option doesn't exist
    ---@return string|number # The option value, or the default value
    function s.Get(opt, default)
        return options[opt] or default
    end

    ---@return table<string, any> # The options as a table
    function s.Data()
        return options
    end

    return setmetatable(s, PointOptions)
end

--- Unit vector in world coordinates in format {x,y,z}. Causes the direction of the construct to be locked to the direction stored in the point throughout the approach to the point.
PointOptions.LOCK_DIRECTION = "lockDir"
--- Meters. How close must the construct be to consider the point reached.
PointOptions.MARGIN = "margin"
--- m/s. Desired speed when the point is reached.
PointOptions.FINAL_SPEED = "finalSpeed"
--- m/s. Desired maximal speed. (equal or less than finalSpeed)
PointOptions.MAX_SPEED = "maxSpeed"
-- Boolean. If true, final speed takese precedence over last-point in route check.
PointOptions.FORCE_FINAL_SPEED = "forcefinalspeed"
-- Boolean. If true, the point can be skipped while traveling along the route
PointOptions.SKIPPABLE = "skippable"

return PointOptions
