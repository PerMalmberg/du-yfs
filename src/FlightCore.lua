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
local calc = require("Calc")

local radToDeg = math.deg
local acos = math.acos
local clamp = utils.clamp
local atan = math.atan
local abs = math.abs

local flushFrequency = 1/60.0

local flightCore = {}
flightCore.__index = flightCore
local singelton = nil

local function new()
    local core = library.GetCoreUnit()
    local ctrl = library.GetController()
    local instance = {
        core = core,
        ctrl = ctrl,
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
        enginesOn = true,
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
        },
        player = {
            position = {
                Current = function()
                    return vec3(ctrl.getMasterPlayerWorldPosition())
                end
            }
        }
    }

    setmetatable(instance, flightCore)

    return instance
end

function flightCore:SetEngines(on)
    self.enginesOn = on
end

---Initiates yaw, roll and pitch stabilization
function flightCore:EnableStabilization(focusPoint)
    self.autoStabilization = {
        rollPid = PID(7.5, 0.01, 3, -25, 25),
        pitchPid = PID(7.5, 0.01, 3, -25, 25),
        yawPid = PID(7.5, 0.01, 3, -25, 25),
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
    self:EnableHoldPosition(self.position.Current(), deadZone)
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
        targetPos = position or self.position.Current(),
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
    system:clearEvent("flush", self.flushHandlerId)
    system:clearEvent("update", self.updateHandlerId)
end

---Returns the alignment offset (-1...0...1) between the construct reference and the target on the plane given by the up and right vectors.
---@param target vec3 The target from which to determine the offset
---@param forward vec3 The vector for which we want to know the offset. Also makes up the plane together with 'right'.
---@param right vec3 The vector that, with 'forward', makes up the plane on which to determine the offset.
---@return number The offset from the direction of the target on the plane. 0 means it is perfectly aligned.
function flightCore:alignmentOffset(target, forward, right)
    -- Create the vector pointing to the target
    local toTarget = target - self.position.Current()
    toTarget:normalize_inplace()

    -- Create a plane, based on the reference and right vectors.
    -- Negate right to get a normal pointing up (right hand rule for cross product)
    local planeNormal = forward:cross(-right):normalize_inplace()
    -- Project the target vector onto the plane
    local projection = toTarget:project_on_plane(planeNormal)

    -- Determine how far off we are from the forward vector
    local diff = projection:dot(forward)

    -- Determine the direction compared to the target
    local opposite = planeNormal:cross(right):dot(forward) < 0
    local rightOfForward
    -- https://math.stackexchange.com/questions/2584451/how-to-get-the-direction-of-the-angle-from-a-dot-product-of-two-vectors
    if opposite then
        -- Other half-circle than target
        rightOfForward = planeNormal:cross(toTarget):dot(-forward) <= 0
    else
        -- Same half-circle as target
        rightOfForward = planeNormal:cross(toTarget):dot(forward) <= 0
    end

    -- Adjust diff such that 0 means fully aligned and we turn the shortest way towards target.
    if rightOfForward then
        diff = 1 - diff
    else
        diff = diff - 1
    end

    return diff
end

function flightCore:deadZone(value, zone)
    if abs(value) < abs(zone) then
        return 0
    end

    return value
end

function flightCore:autoStabilize()
    if self.autoStabilization ~= nil and self.ctrl.getClosestPlanetInfluence() > 0 then
        local downDirection = self.orientation.AlongGravity()

        local yawDiff = self:alignmentOffset(self.autoStabilization.focusPoint, self.orientation.Forward(), self.orientation.Right())
        local yawAcceleration = self.autoStabilization.yawPid:Feed(flushFrequency, 0, -yawDiff) * self.orientation.Up()

        local pitchDiff = self:alignmentOffset(self.autoStabilization.focusPoint, self.orientation.Forward(), self.orientation.Up())
        local pitchAcceleration = self.autoStabilization.pitchPid:Feed(flushFrequency, 0, pitchDiff) * self.orientation.Right()

        local pointAbove = self.position.Current() - downDirection * 10 -- A point above, opposite the down direction
        local rollDiff = self:alignmentOffset(pointAbove, self.orientation.Up(), self.orientation.Right())
        local rollAcceleration = self.autoStabilization.rollPid:Feed(flushFrequency, 0, rollDiff) * self.orientation.Forward()

        self.rotationAcceleration = yawAcceleration + pitchAcceleration + rollAcceleration

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
            self:SetAcceleration(EngineGroup("thrust"), -self.orientation.AlongGravity() * self.core.g() * 1.01)
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

        if self.enginesOn then
            -- Set acceleration values of engines
            self.ctrl.setEngineCommand(self.accelerationGroup:Union(), {self.acceleration:unpack()})
        else
            self.ctrl.setEngineCommand(self.accelerationGroup:Union(), {0, 0, 0})
        end

        -- Set rotational values on adjustors
        self.ctrl.setEngineCommand(self.rotationGroup:Union(), {0, 0, 0}, {self.rotationAcceleration:unpack()})
    end
end

function flightCore:Update()
    --[[
    diag:DrawNumber(0, self.position.Current())
    diag:DrawNumber(1, self.position.Current() + self.orientation.Forward() * 3)
    diag:DrawNumber(2, self.position.Current() + self.orientation.Up() * 3)
    diag:DrawNumber(3, self.position.Current() + self.orientation.Right() * 3)
    local focusPoint = self.player.position.Current()
    local toTarget = focusPoint - self.position.Current()
    toTarget:normalize_inplace()

    -- These tell us how close the toTargetVector is in the respective axis
    -- When fully aligned, these values will be:
    --- diffForward = 1
    --- diffUp = 0
    --- diffRight = 0
    local diffForward = toTarget:dot(self.orientation.Forward())
    local diffUp = toTarget:dot(self.orientation.Up())
    local diffRight = toTarget:dot(self.orientation.Right())



    diag:Info(diffForward, diffUp, diffRight)
]]
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
