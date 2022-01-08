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
local radToDeg = math.deg
local acos = math.acos
local clamp = utils.clamp

local flightCore = {}
flightCore.__index = flightCore
local singelton = nil

local function new()
    local core = library.getCoreUnit()
    local instance = {
        core = core,
        ctrl = library.getController(),
        desiredDirection = vec3(),
        acceleration = vec3(),
        rotationAcceleration = vec3(),
        accelerationGroup = EngineGroup("thrust"),
        rotationGroup = EngineGroup("torque"),
        autoStabilization = nil,
        eventHandlerId = 0,
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

---Initiates yaw and roll towards a point
---@param target vec3 The target point
function flightCore:TurnTowards(target)
    diag:AssertIsVec3(target, "target in PointTowards must be a vec3")
    self.autoStabilization = {
        rollPid = Pid(0.5, 0, 10),
        pitchPid = Pid(0.5, 0, 10),
        yawPid = Pid(10, 0, 10),
        target = target
    }
    self.dirty = true
end

---@param group EngineGroup The engine group to apply the acceleration to
---@param direction vec3 direction we want to travel with the given acceleration
---@param acceleration number m/s2
function flightCore:SetAcceleration(group, direction, acceleration)
    diag:AssertIsTable(group, "group in SetAcceleration must be a table")
    diag:AssertIsVec3(direction, "direction in SetAcceleration must be a vec3")
    diag:AssertIsNumber(acceleration, "acceleration in SetAcceleration must be a number")
    self.accelerationGroup = group
    self.acceleration = direction * acceleration
    self.dirty = true
end

function flightCore:ReceiveEvents()
    self.eventHandlerId = system:onEvent("flush", self.Flush, self)
end

function flightCore:StopEvents()
    self:clearEvent("flush", self.eventHandlerId)
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

function flightCore:Flush()
    self:autoStabilize()

    if self.dirty then
        self.dirty = false

        self.ctrl.setEngineCommand(self.accelerationGroup:Union(), {self.acceleration:unpack()})

        self.ctrl.setEngineCommand(self.rotationGroup:Union(), {0, 0, 0}, {self.rotationAcceleration:unpack()})
    end
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
