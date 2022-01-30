local construct = require("abstraction/Construct")()
local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local calc = require("Calc")
local sharedPanel = require("panel/SharedPanel")()

local control = {}
control.__index = control

AxisControlPitch = 1
AxisControlRoll = 2
AxisControlYaw = 3

---Creates a new AxisControl
---@param maxAcceleration number radians/s2
---@return table A new AxisControl
local function new(maxAcceleration, axis)
    diag:AssertIsNumber(maxAcceleration, "maxAcceleration in AxisControl constructor must be a number")
    diag:AssertIsNumber(axis, "axis in AxisControl constructor must be a number")

    local instance = {
        maxAcc = maxAcceleration,
        ctrl = library.GetController(),
        targetCoordinate = nil,
        Forward = nil,
        Right = nil,
        flushHandlerId = nil,
        updateHandlerId = nil,
        widget = nil,
        currentOffsetAngle = 0
    }

    if axis == AxisControlPitch then
        instance.widget = sharedPanel:Get("AxisControl"):CreateValue("Pitch", "deg")
        instance.Forward = construct.orientation.Forward
        instance.Right = construct.orientation.Up
    elseif axis == AxisControlRoll then
        instance.widget = sharedPanel:Get("AxisControl"):CreateValue("Roll", "deg")
        instance.Forward = construct.orientation.Up
        instance.Right = construct.orientation.Right
    elseif axis == AxisControlYaw then
        instance.widget = sharedPanel:Get("AxisControl"):CreateValue("Yaw", "deg")
        instance.Forward = construct.orientation.Forward
        instance.Right = construct.orientation.Right
    else
        diag:Fail("Invalid axis: " .. axis)
    end

    setmetatable(instance, control)

    return instance
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
        self.currentOffsetAngle = calc.AlignmentOffset(construct.position.Current(), self.targetCoordinate, self.Forward(), self.Right()) * 180
    end
end

function control:Update()
    self.widget:Set(self.currentOffsetAngle)
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
