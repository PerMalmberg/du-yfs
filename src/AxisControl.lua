local construct = require("abstraction/Construct")()
local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local calc = require("Calc")
local sharedPanel = require("panel/SharedPanel")()
local EngineGroup = require("EngineGroup")
local constants = require("Constants")

local abs = math.abs

local control = {}
control.__index = control

AxisControlPitch = 1
AxisControlRoll = 2
AxisControlYaw = 3

---Creates a new AxisControl
---@param maxAngluarVelocity number Max angular velocity in radians/s2
---@return table A new AxisControl
local function new(maxAngluarVelocity, axis)
    diag:AssertIsNumber(maxAngluarVelocity, "maxAcceleration in AxisControl constructor must be a number")
    diag:AssertIsNumber(axis, "axis in AxisControl constructor must be a number")

    local instance = {
        controlledAxis = axis,
        maxVel = maxAngluarVelocity,
        ctrl = library.GetController(),
        targetCoordinate = nil,
        Forward = nil,
        Right = nil,
        flushHandlerId = nil,
        updateHandlerId = nil,
        offsetWidget = nil,
        velocityWidget = nil,
        currentOffsetAngle = 0,
        torqueGroup = EngineGroup("torque"),
        c = 0
    }

    local shared = sharedPanel:Get("AxisControl")
    local o = construct.orientation

    if axis == AxisControlPitch then
        instance.offsetWidget = shared:CreateValue("Pitch", "°")
        instance.Forward = o.Forward
        instance.Right = o.Up
        instance.RotationAxis = o.Right
    elseif axis == AxisControlRoll then
        instance.offsetWidget = shared:CreateValue("Roll", "°")
        instance.Forward = o.Up
        instance.Right = o.Right
        instance.RotationAxis = o.Forward
    elseif axis == AxisControlYaw then
        instance.offsetWidget = shared:CreateValue("Yaw", "°")
        instance.Forward = o.Forward
        instance.Right = o.Right
        instance.RotationAxis = o.Up
    else
        diag:Fail("Invalid axis: " .. axis)
    end

    instance.velocityWidget = shared:CreateValue("Velocity", "°/s")

    setmetatable(instance, control)

    return instance
end

function control:CurrentAngluarVelocity()
    return math.deg((construct.velocity.Angular() * self.RotationAxis()):len())
end

function control:ReceiveEvents()
    self.flushHandlerId = system:onEvent("flush", self.Flush, self)
    self.updateHandlerId = system:onEvent("update", self.Update, self)
end

function control:StopEvents()
    system:clearEvent("flush", self.flushHandlerId)
    system:clearEvent("update", self.updateHandlerId)
end

function control:SetTarget(targetCoordinate)
    self.targetCoordinate = targetCoordinate
end

function control:Flush()
    if self.targetCoordinate ~= nil then
        self.c = self.c + constants.flushTick

        self.currentOffsetAngle =
            calc.AlignmentOffset(construct.position.Current(), self.targetCoordinate, self.Forward(), self.Right()) *
            180
    --[[
        if self.controlledAxis == AxisControlYaw and self.c > 15 and self.c < 16 then
            system.print("qqqqqqqqqqqqqq")
            local acc = math.pi / 4 * self.RotationAxis()
            self.ctrl.setEngineCommand(self.torqueGroup:Union(), {0, 0, 0}, {acc:unpack()})
        end ]]
    end
end

function control:Update()
    self.offsetWidget:Set(self.currentOffsetAngle)
    self.velocityWidget:Set(self:CurrentAngluarVelocity())
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
