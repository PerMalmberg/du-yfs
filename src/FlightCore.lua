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
local vec3 = require("builtin/cpml/vec3")
local EngineGroup = require("EngineGroup")
local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local Brakes = require("Brakes")
local construct = require("abstraction/Construct")()
local AxisControl = require("AxisControl")
local nullVec = vec3()

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
        controllers = {
            pitch = AxisControl(AxisControlPitch),
            roll = AxisControl(AxisControlRoll),
            yaw = AxisControl(AxisControlYaw)
        },
        controlValue = {
            acceleration = vec3(),
            accelerationGroup = EngineGroup("none"),
            desiredDirection = vec3()
        }
    }

    setmetatable(instance, flightCore)

    return instance
end

---Initiates yaw, roll and pitch stabilization
function flightCore:EnableStabilization(focusPointGetter)
    diag:AssertIsFunction(focusPointGetter, "focusPointGetter", "flightCore:EnableStabilization")
    self.autoStabilization = {
        focusPoint = focusPointGetter
    }
end

function flightCore:DisableStabilization()
    self.autoStabilization = nil
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
    self.controllers.pitch:ReceiveEvents()
    self.controllers.roll:ReceiveEvents()
    self.controllers.yaw:ReceiveEvents()
end

function flightCore:StopEvents()
    system:clearEvent("flush", self.flushHandlerId)
    system:clearEvent("update", self.updateHandlerId)
    self.controllers.pitch:StopEvents()
    self.controllers.roll:StopEvents()
    self.controllers.yaw:StopEvents()
end

function flightCore:autoStabilize()
    local as = self.autoStabilization

    if as ~= nil and self.ctrl.getClosestPlanetInfluence() > 0 then
        local ownPos = construct.position.Current()

        local focus = as.focusPoint()

        self.controllers.yaw:SetTarget(focus)
        self.controllers.pitch:SetTarget(focus)

        local pointAbove = ownPos + -construct.orientation.AlongGravity() * 10
        self.controllers.roll:SetTarget(pointAbove)
    end
end

function flightCore:Update()
    self.brakes:Update()
    self:autoStabilize()
end

function flightCore:Flush()
    local c = self.controllers
    c.pitch:Flush(false)
    c.roll:Flush(false)
    c.yaw:Flush(true)
    self.brakes:Flush()

    -- Set controlValue.acceleration values of engines
    --self.ctrl.setEngineCommand(self.controlValue.accelerationGroup:Union(), {self.controlValue.acceleration:unpack()})
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
