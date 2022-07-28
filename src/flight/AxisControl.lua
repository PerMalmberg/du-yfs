local r = require("CommonRequire")
local library = r.library
local vehicle = r.vehicle
local G = vehicle.world.G
local AngVel = vehicle.velocity.localized.Angular
local AngAcc = vehicle.acceleration.localized.Angular
local checks = r.checks
local calc = r.calc
local SignLargestAxis = calc.SignLargestAxis
local nullVec = r.Vec3()
local sharedPanel = require("du-libs:panel/SharedPanel")()
local PID = require("cpml/pid")

local rad2deg = 180 / math.pi
local deg2rad = math.pi / 180
local abs = math.abs
local Sign = calc.Sign

local control = {}
control.__index = control

AxisControlPitch = 1
AxisControlRoll = 2
AxisControlYaw = 3

local finalAcceleration = {}
finalAcceleration[AxisControlPitch] = nullVec
finalAcceleration[AxisControlRoll] = nullVec
finalAcceleration[AxisControlYaw] = nullVec

local function createWidgets(instance, panel, axis)
    instance.wAngle = panel:CreateValue(axis, "°")
    instance.wSpeed = panel:CreateValue("P.Vel", "°/s")
    instance.wAcc = panel:CreateValue("P.Acc", "°/s2")
    instance.wOffset = panel:CreateValue("Offset", "°")
end

---Creates a new AxisControl
---@return table A new AxisControl
local function new(axis)
    checks.IsNumber(axis, "axis", "AxisControl:new")

    local instance = {
        controlledAxis = axis,
        ctrl = library.GetController(),
        updateHandlerId = nil,
        wAngle = nil,
        wSpeed = nil,
        wAcc = nil,
        wOffset = nil,
        maxAcceleration = 360 / 4, -- start value, degrees per second,
        targetCoordinate = nil,
        pid = PID(24, 16, 1600, 0.1) -- 0.5 amortization makes it alot smoother
    }

    local shared = sharedPanel:Get("Axes")
    local o = vehicle.orientation

    if axis == AxisControlPitch then
        createWidgets(instance, shared, "Pitch")
        instance.Reference = o.Forward
        instance.Normal = o.Right
        instance.LocalNormal = vehicle.orientation.localized.Right
    elseif axis == AxisControlRoll then
        createWidgets(instance, shared, "Roll")
        instance.Reference = o.Up
        instance.Normal = o.Forward
        instance.LocalNormal = vehicle.orientation.localized.Forward
    elseif axis == AxisControlYaw then
        createWidgets(instance, shared, "Yaw")
        instance.Reference = o.Forward
        instance.Normal = o.Up
        instance.LocalNormal = vehicle.orientation.localized.Up
    else
        checks.Fail("Invalid axis: " .. axis)
    end

    setmetatable(instance, control)

    return instance
end

function control:ReceiveEvents()
    self.updateHandlerId = system:onEvent("onUpdate", self.Update, self)
end

function control:StopEvents()
    system:clearEvent("update", self.updateHandlerId)
end

function control:SetTarget(targetCoordinate)
    if targetCoordinate == nil then
        self:Disable()
    else
        self.targetCoordinate = targetCoordinate
    end
end

function control:Disable()
    self.targetCoordinate = nil
    finalAcceleration[self.controlledAxis] = nullVec
end

---Returns the current signed angular velocity, in degrees per seconds.
---@return number
function control:Speed()
    local vel = AngVel() * rad2deg
    vel = vel * self.LocalNormal()

    -- The normal vector gives the correct x, y or z axis part of the speed
    -- We need the sign of the speed
    return vel:len() * SignLargestAxis(vel)
end

function control:Acceleration()
    local vel = AngAcc() * rad2deg
    -- The normal vector gives the correct x, y or z axis part of the acceleration
    return (vel * self.LocalNormal()):len()
end

function control:AxisFlush(apply)
    if self.targetCoordinate ~= nil then
        -- Positive offset means we're right of target, clock-wise
        -- Positive acceleration turns counter-clockwise
        -- Positive velocity means we're turning counter-clockwise

        local vecToTarget = self.targetCoordinate - vehicle.position.Current()
        local offset = calc.SignedRotationAngle(self.Normal(), self.Reference(), vecToTarget) * rad2deg
        self.wOffset:Set(calc.Round(offset, 4))

        -- Prefer yaw above pitch by preventing the construct from pitching when the target point is behind.
        -- This prevents construct from ending up upside down while gravity affects us and engines can't keep us afloat.
        if self.controlledAxis == AxisControlPitch then
            if abs(offset) >= 90 and G() > 0 then
                offset = 0
            end
        end

        local sign = Sign(offset)
        local isLeftOf = sign == -1
        local isRightOf = sign == 1
        local speed = self:Speed()
        local movingLeft = Sign(speed) == 1
        local movingRight = Sign(speed) == -1

        local movingTowardsTarget = (isLeftOf and movingRight) or (isRightOf and movingLeft)

        self.pid:inject(offset)

        finalAcceleration[self.controlledAxis] = self:Normal() * self.pid:get() * deg2rad * calc.Ternary(movingTowardsTarget, 0.5, 1)
    end

    if apply then
        self:Apply()
    end
end

function control:Apply()
    local acc = finalAcceleration[AxisControlPitch] + finalAcceleration[AxisControlRoll] + finalAcceleration[AxisControlYaw]
    self.ctrl.setEngineCommand("torque", { 0, 0, 0 }, { acc:unpack() }, 1, 1, "", "", "")
end

function control:Update()
    self.wSpeed:Set(calc.Round(self:Speed(), 2))
    self.wAcc:Set(calc.Round(self:Acceleration(), 2))
end

return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                return new(...)
            end
        }
)