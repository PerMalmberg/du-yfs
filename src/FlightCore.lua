---@diagnostic disable: undefined-doc-name

--[[
    Right hand rule for cross product:
    * Point right flat hand in direction of first arrow
    * Curl fingers in direction of second.
    * Thumb now point in dirction of the resulting third arrow.

    a.b = 0 when vectors are perpendicular.
    a.b = 1 when vectors are orthogonal
    axb = 0 when vectors are parallel

]]
local vec3 = require("builtin/cpml/vec3")
local EngineGroup = require("EngineGroup")
local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local utils = require("builtin/cpml/utils")
local Pid = require("builtin/cpml/pid")
local Brakes = require("Brakes")
local Constants = require("Constants")

local radToDeg = math.deg
local acos = math.acos
local clamp = utils.clamp

local flightCore = {}
flightCore.__index = flightCore
local singelton = nil

local function new()
    local core = library.GetCoreUnit()
    local instance = {
        core = core,
        ctrl = library.GetController(),
        desiredDirection = vec3(),
        accelerationGroup = EngineGroup("none"),
        brakes = Brakes(),
        acceleration = vec3(),
        rotationGroup = EngineGroup("torque"),
        rotationAcceleration = vec3(),
        brakeGroup = EngineGroup("brake"),
        brakeAcceleration = 0,
        autoStabilization = nil,
        flushHandlerId = 0,
        updateHandlerId = 0,
        dirty = false,
        orientation = {
            Up = function()
                -- This points in the current up direction of the construct
                return vec3(core.getConstructWorldOrientationUp())
            end,
            Right = function()
                -- This points in the current right direction of the construct
                return vec3(core.getConstructWorldOrientationRight())
            end,
            Forward = function()
                -- This points in the current forward direction of the construct
                return vec3(core.getConstructWorldOrientationForward())
            end,
            AlongGravity = function()
                -- This points towards the center of the planet, i.e. downwards
                return vec3(core.getWorldVertical())
            end
        },
        velocity = {
            Angular = function()
                return vec3(core.getWorldAngularVelocity())
            end,
            Movement = function()
                return vec3(core.getWorldAbsoluteVelocity())
            end
        },
        position = {
            Current = function()
                return vec3(core.getConstructWorldPos())
            end
        },
        world = {
            AtmoDensity = core.getAtmosphereDensity,
            IsInAtmo = function()
                return core.getAtmosphereDensity() > Constants.atmoToSpaceDensityLimit
            end
        }
    }

    setmetatable(instance, flightCore)

    return instance
end

---Calculates the constructs angle (roll/pitch) based on the two vectors passed in that are used to construct the plane.
---@param forward vec3 The vector that is considered forward in the plane (the axis the plane rotates around).
---@param right vec3 The vector that is considered right in the plane.
---@return number Angle, in degrees, clock-wise reference
function flightCore:angleFromPlane(forward, right)
    diag:AssertIsVec3(forward, "forward in angleFromPlane must be a vec3")
    diag:AssertIsVec3(right, "right in angleFromPlane must be a vec3")
    if self.ctrl.getClosestPlanetInfluence() > 0 then
        local o = self.orientation
        -- Create a horizontal plane orthogonal to the gravity.
        local plane = o.AlongGravity():cross(forward):normalize_inplace()
        -- Now calculate the angle between the plane and construct-right (as if rotated around forward axis).
        local dot = clamp(plane:dot(right), -1, 1) -- Add a clamp here to ensure floating point math doesn't fuck us up. ()
        local angle = radToDeg(acos(dot))
        -- The angle doesn't tell us which way we are rolled so determine that.
        local negate = plane:cross(right):dot(forward)
        if negate < 0 then
            angle = -angle
        end
        return angle
    else
        return 0
    end
end

--- Calculate roll against the horizontal plane. If in space this will be 0
---@return number The roll, in degrees,clock-wise, i.e. left roll away from plane gives negative roll.
function flightCore:CalculateRoll()
    return self:angleFromPlane(self.orientation.Forward(), self.orientation.Right())
end

--- Calculate pitch against the horizontal plane. If in space this will be 0.
--- Negative pitch means tipped forward, down towards planet
function flightCore:CalculatePitch()
    return self:angleFromPlane(self.orientation.Right(), -self.orientation.Forward())
end

---Initiates yaw, roll and pitch stabilization
function flightCore:EnableStabilization()
    self.autoStabilization = {
        rollPid = Pid(0.5, 0, 10),
        pitchPid = Pid(0.5, 0, 10),
        yawPid = Pid(10, 0, 10)
    }
    self.dirty = true
end

function flightCore:DisableStabilization()
    self.autoStabilization = nil
end

---Enables hold position
---@param position vec3 The position to hold
---@param deadZone number If close than this distance (in m) then consider position reached
function flightCore:EnableHoldPosition(position, deadZone)
    if position ~= nil then
        diag:AssertIsVec3(position, "position in EnableHoldPosition must be a vec3")
    end

    self.holdPosition = {
        targetPos = position or self.position.Current(),
        deadZone = deadZone or 1,
        forcePid = Pid(0.2, 0, 10)
    }
end

function flightCore:DisableHoldPosition()
    self.holdPosition = nil
end

---@param group EngineGroup The engine group to apply the acceleration to
---@param acceleration vec3 Acceleration in m/s2, in world coordinates
function flightCore:SetAcceleration(group, acceleration)
    diag:AssertIsTable(group, "group in SetAcceleration must be a table")
    diag:AssertIsVec3(acceleration, "acceleration in SetAcceleration must be a vec3")
    self.accelerationGroup = group
    self.acceleration = acceleration
    self.dirty = true
end

---Sets the brakes to the given force
---@param brakeAcceleration number The force, in
function flightCore:SetBrakes(brakeAcceleration)
    diag:AssertIsNumber(brakeAcceleration, "brakeAcceleration in SetBrakes must be a number")
    self.brakeAcceleration = brakeAcceleration
end

function flightCore:ReceiveEvents()
    self.flushHandlerId = system:onEvent("flush", self.Flush, self)
    self.updateHandlerId = system:onEvent("update", self.Update, self)
end

function flightCore:StopEvents()
    self:clearEvent("flush", self.flushHandlerId)
    self:clearEvent("flush", self.updateHandlerId)
end

function flightCore:autoStabilize()
    if self.autoStabilization ~= nil then
        local rollAngle = self:CalculateRoll()
        self.autoStabilization.rollPid:inject(-rollAngle) -- We're passing in the error (as we want to be at 0)
        local rollAcceleration = self.autoStabilization.rollPid:get() * self.orientation.Forward()

        local pitchAngle = self:CalculatePitch()
        self.autoStabilization.pitchPid:inject(-pitchAngle) -- We're passing in the error (as we want to be at 0)
        local pitchAcceleration = self.autoStabilization.pitchPid:get() * self.orientation.Right()

        local yawVelocity = self.velocity.Angular() * self.orientation.Up()
        self.autoStabilization.yawPid:inject(-yawVelocity)
        local yawAcceleration = self.autoStabilization.yawPid:get() * self.orientation.Up()

        self.rotationAcceleration = rollAcceleration + pitchAcceleration + yawAcceleration

        self.dirty = true
    end
end

function flightCore:autoHoldPosition()
    local h = self.holdPosition
    if h ~= nil then
        local movementDirection = self.velocity.Movement():normalize_inplace()
        local distanceToTarget = h.targetPos - self.position.Current()
        local directionToTarget = distanceToTarget:normalize()
        local movingTowardsTarget = movementDirection:dot(directionToTarget) > 0

        if movingTowardsTarget then
            self:SetBrakes(0)
        else
            -- Moving away from the target, apply brakes
            self:SetBrakes(self.core.g() * 10)
        end

        if distanceToTarget:len() < h.deadZone then
            self:SetBrakes(self.core.g() * 10)
            self:SetAcceleration(EngineGroup("thrust"), -self.orientation.AlongGravity() * self.core.g())
        else
            local acceleration = directionToTarget:normalize() * self.core.g() * 0.1
            -- If target point is above, add the extra acceleration upwards to counter gravity
            if directionToTarget:dot(self.orientation.AlongGravity()) <= 0 then
                acceleration = acceleration - self.orientation.AlongGravity():normalize_inplace() * self.core.g()
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
        local brakeVector = -self.velocity.Movement():normalize() * self.brakeAcceleration
        self.ctrl.setEngineCommand(self.brakeGroup:Union(), {brakeVector:unpack()})

        -- Set acceleration values of engines
        self.ctrl.setEngineCommand(self.accelerationGroup:Union(), {self.acceleration:unpack()})

        -- Set rotational values on adjustors
        self.ctrl.setEngineCommand(self.rotationGroup:Union(), {0, 0, 0}, {self.rotationAcceleration:unpack()})
    end
end

function flightCore:Update()
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
