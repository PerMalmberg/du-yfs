require("abstraction/Vehicle")
local si, Vec3, PID                     = require("Singletons"), require("math/Vec3"), require("cpml/pid")
local yfsC, pub, calc                   = si.constants, si.pub, si.calc

local SignLargestAxis, SignedRotationAngle, setEngineCommand,
LightConstructMassThreshold, nullVec    =
    calc.SignLargestAxis,
    calc.SignedRotationAngle,
    unit.setEngineCommand,
    yfsC.flight.lightConstructMassThreshold,
    Vec3.zero

local rad2deg                           = 180 / math.pi

local control                           = {}
control.__index                         = control

---@enum ControlledAxis
ControlledAxis                          = {
    Pitch = 1,
    Roll = 2,
    Yaw = 3,
}

local finalAcceleration                 = {} ---@type Vec3[]
finalAcceleration[ControlledAxis.Pitch] = nullVec
finalAcceleration[ControlledAxis.Roll]  = nullVec
finalAcceleration[ControlledAxis.Yaw]   = nullVec

---@class AxisControl
---@field ReceiveEvents fun()
---@field StopEvents fun()
---@field Disable fun()
---@field Speed fun():number
---@field Acceleration fun():number
---@field AxisFlush fun(deltaTime:number)
---@field Update fun()
---@field SetTarget fun(target:Vec3)
---@field OffsetDegrees fun():number
---@field Apply fun()

local AxisControl                       = {}
AxisControl.__index                     = AxisControl


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

    -- taylor local lightPid = PID(1, 10, 100, 0.1)

    local set, axisPids = require("Settings").Instance(), yfsC.flight.axis
    local l = axisPids.light
    local h = axisPids.heavy

    local lightPid = PID(l.p, l.i, l.d, l.a)
    local heavyPid = PID(h.p, h.i, h.d, h.a)
    set.Callback("lightp", function(v) lightPid = PID(v, lightPid.i, lightPid.d, lightPid.amortization) end)
    set.Callback("lighti", function(v) lightPid = PID(lightPid.p, v, lightPid.d, lightPid.amortization) end)
    set.Callback("lightd", function(v) lightPid = PID(lightPid.p, lightPid.i, v, lightPid.amortization) end)
    set.Callback("lighta", function(v) lightPid = PID(lightPid.p, lightPid.i, lightPid.d, v) end)

    set.Callback("heavyp", function(v) heavyPid = PID(v, heavyPid.i, heavyPid.d, heavyPid.amortization) end)
    set.Callback("heavyi", function(v) heavyPid = PID(heavyPid.p, v, heavyPid.d, heavyPid.amortization) end)
    set.Callback("heavyd", function(v) heavyPid = PID(heavyPid.p, heavyPid.i, v, heavyPid.amortization) end)
    set.Callback("heavya", function(v) heavyPid = PID(heavyPid.p, heavyPid.i, heavyPid.d, v) end)

    local pubTopic
    local lastReadMass = TotalMass()

    local axisData = {
        speed = 0,
        acceleration = 0,
        offset = 0 -- in degrees
    }

    if axis == ControlledAxis.Pitch then
        reference = Forward
        normal = Right
        localNormal = LocalRight
        pubTopic = "PitchData"
    elseif axis == ControlledAxis.Roll then
        reference = Up
        normal = Forward
        localNormal = LocalForward
        pubTopic = "RollData"
    elseif axis == ControlledAxis.Yaw then
        reference = Forward
        normal = Up
        localNormal = LocalUp
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
            s.Disable()
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
        local vel = LocalAngVel() * rad2deg
        vel = vel * localNormal()

        -- The normal vector gives the correct x, y or z axis part of the speed
        -- We need the sign of the speed
        return vel:Len() * SignLargestAxis(vel)
    end

    function s.Acceleration()
        local vel = LocalAngAcc() * rad2deg
        -- The normal vector gives the correct x, y or z axis part of the acceleration
        return (vel * localNormal()):Len()
    end

    ---@param deltaTime number
    function s.AxisFlush(deltaTime)
        if targetCoordinate then
            -- Positive offset means we're right of target, clock-wise
            -- Positive acceleration turns counter-clockwise
            -- Positive velocity means we're turning counter-clockwise

            local vecToTarget = (targetCoordinate - Current()):Normalize()
            local offset = SignedRotationAngle(normal(), reference(), vecToTarget)
            axisData.offset = offset * rad2deg

            lightPid:inject(offset)
            heavyPid:inject(offset)

            local v
            if lastReadMass > LightConstructMassThreshold then
                v = heavyPid:get()
            else
                v = lightPid:get()
            end

            finalAcceleration[axis] = normal() * v
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
