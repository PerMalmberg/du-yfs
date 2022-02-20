---@diagnostic disable: undefined-doc-name

--[[
    Right hand rule for cross product:
    * Point right flat hand in direction of first arrow
    * Curl fingers in direction of second.
    * Thumb now point in dirction of the resulting third arrow.

    a.b = 0 when vectors are orthogonal.
    a.b = 1 when vectors are parallel.
    axb = 0 when vectors are parallel.

]]
local vec3 = require("cpml/vec3")
local EngineGroup = require("EngineGroup")
local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local Brakes = require("Brakes")
local construct = require("abstraction/Construct")()
local AxisControl = require("AxisControl")
local MoveControl = require("movement/MoveControl")

local flightCore = {}
flightCore.__index = flightCore
local singelton = nil

local function new()
    local ctrl = library.GetController()
    local instance = {
        ctrl = ctrl,
        brakes = Brakes(),
        thrustGroup = EngineGroup("thrust"),
        autoStabilization = nil,
        flushHandlerId = 0,
        updateHandlerId = 0,
        pitch = AxisControl(AxisControlPitch),
        roll = AxisControl(AxisControlRoll),
        yaw = AxisControl(AxisControlYaw),
        movement = MoveControl()
    }

    setmetatable(instance, flightCore)

    return instance
end

---Enables hold position
---@param positionGetter vec3 A function that returns the position to hold
---@param deadZone number If close than this distance (in m) then consider position reached
function flightCore:EnableHoldPosition(positionGetter, deadZone)
    diag:AssertIsFunction(positionGetter, "position", "flightCore:EnableHoldPosition")
    if deadZone ~= nil then
        diag:AssertIsNumber(deadZone, "deadZone", "flightCore:EnableHoldPosition")
    end

    self.holdPosition = {
        targetPos = positionGetter,
        deadZone = deadZone or 1
    }
end

function flightCore:DisableHoldPosition()
    self.holdPosition = nil
end

function flightCore:ReceiveEvents()
    self.flushHandlerId = system:onEvent("flush", self.Flush, self)
    self.updateHandlerId = system:onEvent("update", self.Update, self)
    self.pitch:ReceiveEvents()
    self.roll:ReceiveEvents()
    self.yaw:ReceiveEvents()
end

function flightCore:StopEvents()
    system:clearEvent("flush", self.flushHandlerId)
    system:clearEvent("update", self.updateHandlerId)
    self.pitch:StopEvents()
    self.roll:StopEvents()
    self.yaw:StopEvents()
end

function flightCore:Align()
    local behaviour = self.movement:Current()

    local target
    local topSideAlignment
    if behaviour ~= nil then
        target = behaviour.AlignTo()
        topSideAlignment = behaviour.TopSideAlignment()
    end

    if target ~= nil then
        self.yaw:SetTarget(target)
        self.pitch:SetTarget(target)
    else
        self.yaw:Disable()
        self.pitch:Disable()
    end

    if topSideAlignment ~= nil then
        self.roll:SetTarget(topSideAlignment)
    else
        self.roll:Disable()
    end
end

function flightCore:Update()
    self.brakes:Update()
    self:Align()
end

function flightCore:Flush()
    self.pitch:Flush(false)
    self.roll:Flush(false)
    self.yaw:Flush(true)
    self.brakes:Flush()
    self.movement:Flush()
end

-- The module
return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            if singelton == nil then
                singelton = new()
            end
            return singelton
        end
    }
)
