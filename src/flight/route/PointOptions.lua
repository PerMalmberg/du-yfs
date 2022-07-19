local PointOptions = {}
PointOptions.__index = PointOptions

function PointOptions:New(optionData)
    local self = {
        options = optionData or {}
    }

    function self:Set(opt, value)
        self.options[opt] = value
    end

    function self:Get(opt, default)
        return self.options[opt] or default
    end

    function self:Data()
        return self.options
    end

    return setmetatable(self, PointOptions)
end

PointOptions.LOCK_DIRECTION = "lockDir" -- unit vector in world coordinates in format {x,y,z}. Causes the direction of the construct to be locked to the direction stored in the point throughout the approach to the point.
PointOptions.USE_WINGS = "useWings" -- boolean. Construct behaves as if it had wings, i.e. it will pitch/yaw/roll
PointOptions.MARGIN = "margin" -- meters. How close must the construct be to consider the point reached.
PointOptions.MAX_SPEED = "maxSpeed" -- m/s. Desired approach speed.
PointOptions.PRECISION = "precision" -- boolean. If true, the approach to the point will be done using precision mode. Enable this for maneuvers like straight up/down travel

return PointOptions