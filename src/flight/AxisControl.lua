local r = require("CommonRequire")
local vehicle = r.vehicle
local calc = r.calc
local G = vehicle.world.G
local nullVec = r.Vec3.New()
local AngVel = vehicle.velocity.localized.Angular
local AngAcc = vehicle.acceleration.localized.Angular
local SignLargestAxis = calc.SignLargestAxis
local PID = require("cpml/pid")
local pub = require("util/PubSub").Instance()

local rad2deg = 180 / math.pi
local deg2rad = math.pi / 180
local abs = math.abs
local Sign = calc.Sign

local control = {}
control.__index = control

---@enum ControlledAxis
ControlledAxis = {
    Pitch = 1,
    Roll = 2,
    Yaw = 3,
}


local finalAcceleration = {} ---@type Vec3[]
finalAcceleration[ControlledAxis.Pitch] = nullVec
finalAcceleration[ControlledAxis.Roll] = nullVec
finalAcceleration[ControlledAxis.Yaw] = nullVec

---@class AxisControl
---@field ReceiveEvents fun()
---@field StopEvents fun()
---@field Disable fun()
---@field Speed fun():number
---@field Acceleration fun():number
---@field AxisFlush fun(apply:boolean)
---@field Update fun()
---@field SetTarget fun(target:Vec3)

local AxisControl = {}
AxisControl.__index = AxisControl


---Creates a new AxisControl
---@param axis ControlledAxis
---@return AxisControl A new AxisControl
function AxisControl.New(axis)
    local s = {}

    local reference = nil ---@type fun():Vec3
    local normal = nil ---@type fun():Vec3
    local localNormal = nil ---@type fun():Vec3

    local controlledAxis = axis
    local updateHandlerId = nil
    local targetCoordinate = nil ---@type Vec3|nil
    local pid = PID(24, 16, 1600, 0.1) -- 0.5 amortization makes it alot smoother
    local pubTopic

    local axisData = {
        angle = 0,
        speed = 0,
        acceleration = 0,
        offset = 0
    }

    local o = vehicle.orientation

    if axis == ControlledAxis.Pitch then
        reference = o.Forward
        normal = o.Right
        localNormal = vehicle.orientation.localized.Right
        pubTopic = "PitchData"
    elseif axis == ControlledAxis.Roll then
        reference = o.Up
        normal = o.Forward
        localNormal = vehicle.orientation.localized.Forward
        pubTopic = "RollData"
    elseif axis == ControlledAxis.Yaw then
        reference = o.Forward
        normal = o.Up
        localNormal = vehicle.orientation.localized.Up
        pubTopic = "YawData"
    end

    function s.ReceiveEvents()
        updateHandlerId = system:onEvent("onUpdate", s.Update, s)
    end

    function s.StopEvents()
        system:clearEvent("update", updateHandlerId)
    end

    ---Set the alignment target/point
    ---@param target Vec3
    function s.SetTarget(target)
        if target == nil then
            s:Disable()
        else
            targetCoordinate = target
        end
    end

    function s.Disable()
        targetCoordinate = nil
        finalAcceleration[controlledAxis] = nullVec
    end

    ---Returns the current signed angular velocity, in degrees per seconds.
    ---@return number
    function s.Speed()
        local vel = AngVel() * rad2deg
        vel = vel * localNormal()

        -- The normal vector gives the correct x, y or z axis part of the speed
        -- We need the sign of the speed
        return vel:Len() * SignLargestAxis(vel)
    end

    function s.Acceleration()
        local vel = AngAcc() * rad2deg
        -- The normal vector gives the correct x, y or z axis part of the acceleration
        return (vel * localNormal()):Len()
    end

    ---@param apply boolean
    function s.AxisFlush(apply)
        if targetCoordinate ~= nil then
            -- Positive offset means we're right of target, clock-wise
            -- Positive acceleration turns counter-clockwise
            -- Positive velocity means we're turning counter-clockwise

            local vecToTarget = targetCoordinate - vehicle.position.Current()
            local offset = calc.SignedRotationAngle(normal(), reference(), vecToTarget) * rad2deg
            axisData.offset = offset

            -- Prefer yaw above pitch by preventing the construct from pitching when the target point is behind.
            -- This prevents construct from ending up upside down while gravity affects us and engines can't keep us afloat.
            if s.controlledAxis == ControlledAxis.Pitch then
                if abs(offset) >= 90 and G() > 0 then
                    offset = 0
                end
            end

            local sign = Sign(offset)
            local isLeftOf = sign == -1
            local isRightOf = sign == 1
            local speed = s:Speed()
            local movingLeft = Sign(speed) == 1
            local movingRight = Sign(speed) == -1

            local movingTowardsTarget = (isLeftOf and movingRight) or (isRightOf and movingLeft)

            pid:inject(offset)

            finalAcceleration[controlledAxis] = normal() * pid:get() * deg2rad *
                calc.Ternary(movingTowardsTarget, 0.5, 1)
        end

        if apply then
            local acc = finalAcceleration[ControlledAxis.Pitch] + finalAcceleration[ControlledAxis.Roll] +
                finalAcceleration[ControlledAxis.Yaw]
            unit.setEngineCommand("torque", { 0, 0, 0 }, { acc:Unpack() }, true, true, "", "", "", 0.1)
        end
    end

    function s.Update()
        axisData.speed = s.Speed()
        axisData.acceleration = s.Acceleration()
        pub.Publish(pubTopic, axisData)
    end

    return setmetatable(s, control)
end

return AxisControl
