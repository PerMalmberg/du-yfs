local PointOptions = {}
PointOptions.__index = PointOptions

function PointOptions:New()
    local self = {
        options = {}
    }

    function self:Set(opt, value)
        self.options[opt] = value
    end

    function self:Get(opt, default)
        return self.options[opt] or default
    end

    return setmetatable(self, PointOptions)
end

PointOptions.LOCK_DIRECTION = "lockDir" -- unit vector in world coordinates. Causes the direction of the construct to be locked to the direction stored in the point throughout the approach to the point.
PointOptions.USE_WINGS = "useWings" -- boolean. Construct behaves as if it had wings, i.e. it will pitch/yaw/roll
PointOptions.MARGIN = "margin" -- meters. How close must the construct be to consider the point reached.
PointOptions.MAX_SPEED = "maxSpeed" -- m/s. Desired approach speed.

return PointOptions