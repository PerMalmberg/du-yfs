local Vec3 = require("math/Vec3")
local vehicle = require("abstraction/Vehicle").New()
local calc = require("util/Calc")
local TotalMass = vehicle.mass.Total
local nullVec = Vec3.zero
local yfsConstants = require("YFSConstants")
local LightConstructMassThreshold = yfsConstants.flight.lightConstructMassThreshold
local AngVel = vehicle.velocity.localized.Angular
local AngAcc = vehicle.acceleration.localized.Angular
local SignLargestAxis = calc.SignLargestAxis
local SignedRotationAngle = calc.SignedRotationAngle
local setEngineCommand = unit.setEngineCommand
local PID = require("cpml/pid")
local pub = require("util/PubSub").Instance()

local rad2deg = 180 / math.pi
local deg2rad = math.pi / 180

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
---@field AxisFlush fun()
---@field Update fun()
---@field SetTarget fun(target:Vec3)
---@field OffsetDegrees fun():number
---@field Apply fun()

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

    local updateHandlerId = nil
    local targetCoordinate = nil ---@type Vec3|nil

    local lightPid = PID(6.5, 20, 1600, 0.1)
    local heavyPid = PID(6, 1, 1600, 0.1)
    local pubTopic
    local lastReadMass = TotalMass()

    local axisData = {
        speed = 0,
        acceleration = 0,
        offset = 0 -- in degrees
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
        finalAcceleration[axis] = nullVec
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

    function s.AxisFlush()
        if targetCoordinate ~= nil then
            -- Positive offset means we're right of target, clock-wise
            -- Positive acceleration turns counter-clockwise
            -- Positive velocity means we're turning counter-clockwise

            local vecToTarget = (targetCoordinate - vehicle.position.Current()):Normalize()
            local offset = SignedRotationAngle(normal(), reference(), vecToTarget) * rad2deg
            axisData.offset = offset

            lightPid:inject(offset)
            heavyPid:inject(offset)

            local v
            if lastReadMass > LightConstructMassThreshold then
                v = heavyPid:get()
            else
                v = lightPid:get()
            end

            finalAcceleration[axis] = normal() * v * deg2rad
        end
    end

    function s.Apply()
        local acc = finalAcceleration[ControlledAxis.Pitch] + finalAcceleration[ControlledAxis.Roll] +
            finalAcceleration[ControlledAxis.Yaw]
        setEngineCommand("torque", { 0, 0, 0 }, { acc:Unpack() }, true, true, "", "", "", 0.1)
    end

    function s.Update()
        axisData.speed = s.Speed()
        axisData.acceleration = s.Acceleration()
        pub.Publish(pubTopic, axisData)
        lastReadMass = TotalMass()
    end

    ---Returns the current offset, in degrees
    ---@return number
    function s.OffsetDegrees()
        return axisData.offset
    end

    return setmetatable(s, control)
end

return AxisControl
