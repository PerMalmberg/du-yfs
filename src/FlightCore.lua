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
        dirty = false,
        controllers = {
            pitch = AxisControl(AxisControlPitch),
            roll = AxisControl(AxisControlRoll),
            yaw = AxisControl(AxisControlYaw)
        },
        controlValue = {
            acceleration = vec3(),
            accelerationGroup = EngineGroup("none"),
            desiredDirection = vec3(),
            engineOn = true
        },
        currentStatus = {
            rollDiff = 0,
            pitchDiff = 0,
            yawDiff = 0
        }
    }

    setmetatable(instance, flightCore)

    return instance
end

function flightCore:SetEngines(on)
    self.controlValue.engineOn = on
end

---Initiates yaw, roll and pitch stabilization
function flightCore:EnableStabilization(focusPointGetter)
    diag:AssertIsFunction(focusPointGetter)
    self.autoStabilization = {
        focusPoint = focusPointGetter
    }
    self.dirty = true
end

function flightCore:DisableStabilization()
    self.autoStabilization = nil
end

function flightCore:HoldCurrentPosition(deadZone)
    if deadZone ~= nil then
        diag:AssertIsNumber(deadZone, "deadZone in HoldCurrentPosition must be a number")
    end
    self:EnableHoldPosition(
        function()
            return construct.position.Current()
        end,
        deadZone
    )
end

---Enables hold position
---@param positionGetter vec3 A function that returns the position to hold
---@param deadZone number If close than this distance (in m) then consider position reached
function flightCore:EnableHoldPosition(positionGetter, deadZone)
    diag:AssertIsFunction(positionGetter, "position in EnableHoldPosition must be a function")
    if deadZone ~= nil then
        diag:AssertIsNumber(deadZone, "deadZone in EnableHoldPosition must be a number")
    end

    self.holdPosition = {
        targetPos = positionGetter,
        deadZone = deadZone or 1
    }
end

function flightCore:DisableHoldPosition()
    self.holdPosition = nil
end

---@param group EngineGroup The engine group to apply the acceleration to
---@param acceleration vec3 Acceleration in m/s2, in world coordinates
function flightCore:SetAcceleration(group, acceleration)
    diag:AssertIsTable(group, "group in SetAcceleration must be a table")
    diag:AssertIsVec3(acceleration, "acceleration in acceleration must be a vec3")
    local cv = self.controlValue
    cv.accelerationGroup = group
    cv.acceleration = acceleration
    self.dirty = true
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

function flightCore:autoHoldPosition()
    local h = self.holdPosition
    if h ~= nil then
        local movementDirection = construct.velocity.Movement():normalize_inplace()
        local distanceToTarget = h.targetPos() - construct.position.Current()
        local directionToTarget = distanceToTarget:normalize()
        local movingTowardsTarget = movementDirection:dot(directionToTarget) > 0

        local g = construct.world.G()

        if movingTowardsTarget then
            self.brakes:Set(0)
        else
            -- Moving away from the target, apply brakes
            self.brakes:Set()
        end

        local dist = distanceToTarget:len()
        if dist < h.deadZone or self.brakes:BreakDistance() >= dist then
            self.brakes:Set()
            self:SetAcceleration(self.thrustGroup, -construct.orientation.AlongGravity() * g * 1.01)
        else
            -- Start with countering gravity
            local acceleration = -construct.orientation.AlongGravity():normalize_inplace() * g
            acceleration = acceleration + directionToTarget:normalize() * g * 0.1
            -- If target point is below, remove a slight bit of force
            if directionToTarget:dot(construct.orientation.AlongGravity()) > 0 then
                acceleration = acceleration * 0.98
            end

            self:SetAcceleration(self.thrustGroup, acceleration)
        end
    end
end

function flightCore:Flush()
    local c = self.controllers
    c.pitch:Flush(false)
    c.roll:Flush(false)
    c.yaw:Flush(true)
    self.brakes:Flush()
    self:autoHoldPosition()

    if self.dirty then
        self.dirty = false

        if self.controlValue.engineOn then
            -- Set controlValue.acceleration values of engines
            self.ctrl.setEngineCommand(self.controlValue.accelerationGroup:Union(), {self.controlValue.acceleration:unpack()})
        end
    end
end

function flightCore:Update()
    self.brakes:Update()
    self:autoStabilize()
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
