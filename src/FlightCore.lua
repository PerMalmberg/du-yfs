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
local vec2 = require("builtin/cpml/vec2")
local EngineGroup = require("EngineGroup")
local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local utils = require("builtin/cpml/utils")
local PID = require("PID")
local Brakes = require("Brakes")
local Constants = require("Constants")
local construct = require("abstraction/Construct")()
local calc = require("Calc")

local radToDeg = math.deg
local acos = math.acos
local clamp = utils.clamp
local atan = math.atan
local abs = math.abs

local flushFrequency = 1 / 60.0

local panel = require("panel/Panel")("FlightCore")

local flightCore = {}
flightCore.__index = flightCore
local singelton = nil

local function new()
    local ctrl = library.GetController()
    local instance = {
        core = core,
        ctrl = ctrl,
        brakes = Brakes(),
        rotationGroup = EngineGroup("torque"),
        brakeGroup = EngineGroup("brake"),
        autoStabilization = nil,
        flushHandlerId = 0,
        updateHandlerId = 0,
        dirty = false,
        controlValue = {
            acceleration = vec3(),
            accelerationGroup = EngineGroup("none"),
            desiredDirection = vec3(),
            engineOn = true,
            brakeAcceleration = vec3()
        },
        widgets = {
            rollDiff = panel:CreateValue("Roll", "dot"),
            pitchDiff = panel:CreateValue("Pitch", "dot"),
            yawDiff = panel:CreateValue("Yaw", "dot")
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
function flightCore:EnableStabilization(focusPoint)
    self.autoStabilization = {
        rollPid = PID(10, 0.05, 4, -25, 25),
        pitchPid = PID(10, 0.15, 4, -25, 25),
        yawPid = PID(10, 0.15, 4, -25, 25),
        focusPoint = focusPoint
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
    self:EnableHoldPosition(construct.position.Current(), deadZone)
end

---Enables hold position
---@param position vec3 The position to hold
---@param deadZone number If close than this distance (in m) then consider position reached
function flightCore:EnableHoldPosition(position, deadZone)
    diag:AssertIsVec3(position, "position in EnableHoldPosition must be a vec3")
    if deadZone ~= nil then
        diag:AssertIsNumber(deadZone, "deadZone in EnableHoldPosition must be a number")
    end

    self.holdPosition = {
        targetPos = position or construct.position.Current(),
        deadZone = deadZone or 1,
        forcePid = PID(0.2, 0, 10, -10, 10)
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

---Sets the brakes to the given force
---@param brakeAcceleration number The force, in
function flightCore:SetBrakes(brakeAcceleration)
    diag:AssertIsNumber(brakeAcceleration, "acceleration in SetBrakes must be a number")
    self.controlValue.brakeAcceleration = brakeAcceleration
end

function flightCore:ReceiveEvents()
    self.flushHandlerId = system:onEvent("flush", self.Flush, self)
    self.updateHandlerId = system:onEvent("update", self.Update, self)
end

function flightCore:StopEvents()
    system:clearEvent("flush", self.flushHandlerId)
    system:clearEvent("update", self.updateHandlerId)
end

function flightCore:deadZone(value, zone)
    if abs(value) < abs(zone) then
        return 0
    end

    return value
end

function flightCore:autoStabilize()
    local as = self.autoStabilization

    if as ~= nil and self.ctrl.getClosestPlanetInfluence() > 0 then
        local downDirection = construct.orientation.AlongGravity()

        --as.focusPoint = self.player.position.Current() -- QQQ

        local c = self.currentStatus
        local ownPos = construct.position.Current()

        c.yawDiff = calc.AlignmentOffset(ownPos, as.focusPoint, construct.orientation.Forward(), construct.orientation.Right())
        local yawAcceleration = as.yawPid:Feed(flushFrequency, 0, -c.yawDiff) * construct.orientation.Up()

        c.pitchDiff = calc.AlignmentOffset(ownPos, as.focusPoint, construct.orientation.Forward(), construct.orientation.Up())
        local pitchAcceleration = as.pitchPid:Feed(flushFrequency, 0, c.pitchDiff) * construct.orientation.Right()

        local pointAbove = ownPos - downDirection * 10 -- A point above, opposite the down direction
        c.rollDiff = calc.AlignmentOffset(ownPos, pointAbove, construct.orientation.Up(), construct.orientation.Right())
        local rollAcceleration = as.rollPid:Feed(flushFrequency, 0, c.rollDiff) * construct.orientation.Forward()

        self.controlValue.rotationAcceleration = yawAcceleration + pitchAcceleration + rollAcceleration

        self.dirty = true
    end
end

function flightCore:autoHoldPosition()
    local h = self.holdPosition
    if h ~= nil then
        local movementDirection = construct.velocity.Movement():normalize_inplace()
        local distanceToTarget = h.targetPos - construct.position.Current()
        local directionToTarget = distanceToTarget:normalize()
        local movingTowardsTarget = movementDirection:dot(directionToTarget) > 0

        local g = construct.world.G()

        if movingTowardsTarget then
            self:SetBrakes(0)
        else
            -- Moving away from the target, apply brakes
            self:SetBrakes(g * 10)
        end

        if distanceToTarget:len() < h.deadZone then
            self:SetBrakes(g * 10)
            self:SetAcceleration(EngineGroup("thrust"), -construct.orientation.AlongGravity() * g * 1.01)
        else
            local acceleration = directionToTarget:normalize() * g * 0.1
            -- If target point is above, add the extra acceleration upwards to counter gravity
            if directionToTarget:dot(construct.orientation.AlongGravity()) <= 0 then
                acceleration = acceleration - construct.orientation.AlongGravity():normalize_inplace() * g
            end

            self:SetAcceleration(EngineGroup("thrust"), acceleration)
        end
    end
end

function flightCore:Flush()
    self:autoStabilize()
    self:autoHoldPosition()

    if self.dirty then
        self.dirty = false

        -- Calculate brake vector and set brake value
        -- The brake vector must point against the direction of travel, so negate it.
        local brakeVector = -construct.velocity.Movement():normalize() * self.controlValue.brakeAcceleration
        self.ctrl.setEngineCommand(self.brakeGroup:Union(), {brakeVector:unpack()})

        if self.controlValue.engineOn then
            -- Set controlValue.acceleration values of engines
            self.ctrl.setEngineCommand(
                self.controlValue.accelerationGroup:Union(),
                {self.controlValue.acceleration:unpack()}
            )
        else
            self.ctrl.setEngineCommand(self.controlValue.accelerationGroup:Union(), {0, 0, 0})
        end

        -- Set rotational values on adjustors
        self.ctrl.setEngineCommand(
            self.rotationGroup:Union(),
            {0, 0, 0},
            {self.controlValue.rotationAcceleration:unpack()}
        )
    end
end

function flightCore:Update()
    self.widgets.rollDiff:Set(self.currentStatus.rollDiff)
    self.widgets.pitchDiff:Set(self.currentStatus.pitchDiff)
    self.widgets.yawDiff:Set(self.currentStatus.yawDiff)
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
