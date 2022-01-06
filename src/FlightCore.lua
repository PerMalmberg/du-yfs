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

local vec3 = require("builtin/vec3")
local EngineGroup = require("EngineGroup")
local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local utils = require("builtin/cpml/utils")
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
        eventHandlerId = 0,
        dirty = false,
        orientation = {
            Up = function()
                -- This points in the current up direction of the construct
                return vec3(core.getConstructWorldOrientationUp())
            end,
            Down = function()
                -- This points in the current down direction of the construct
                return -vec3(core.getConstructWorldOrientationUp())
            end,
            Right = function()
                -- This points in the current right direction of the construct
                return vec3(core.getConstructWorldOrientationRight())
            end,
            Left = function()
                -- This points in the current up direction of the construct
                return -vec3(core.getConstructWorldOrientationRight())
            end,
            Forward = function()
                -- This points in the current forward direction of the construct
                return vec3(core.getConstructWorldOrientationForward())
            end,
            Backward = function()
                -- This points in the current forward direction of the construct
                return -vec3(core.getConstructWorldOrientationForward())
            end,
            AlongGravity = function()
                -- This points towards the center of the planet, i.e. downwards
                return vec3(core.getWorldVertical())
            end,
            AwayFromGravity = function()
                -- This points towards the center of the planet, i.e. downwards
                return vec3(core.getWorldVertical())
            end
        }
    }

    setmetatable(instance, flightCore)

    return instance
end

---Calculates the constructs angle (roll/pitch) based on the two vectors passed in that are used to construct the plane.
---@param forward vec3
---@param right vec3
---@return number Angle, in degrees, clock-wise reference
function flightCore:angleFromPlane(forward, right)
    diag:AssertIsVec3(forward, "forward in angleFromPlane must be a vec3")
    diag:AssertIsVec3(right, "right in angleFromPlane must be a vec3")
    if self.ctrl.getClosestPlanetInfluence() > 0 then
        local o = self.orientation
        -- Create a horizontal plane orthogonal to the gravity.
        local plane = o.AlongGravity():cross(forward):normalize_inplace()
        -- Now calculate the angle between the plane and construct-right (as if rotated around forward axis).
        local dot = plane:dot(right)
        diag:Info("dot", dot)
        local angle = radToDeg(acos(dot))
        -- The angle doesn't tell us which way we are rolled so determine that.
        local negate = plane:cross(right):dot(forward)
        diag:Info("negate", negate)
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

function flightCore:CalculatePitch()
    return self:angleFromPlane(self.orientation.Right(), self.orientation.Backward())
end

---Initiates yaw and roll towards a point
---@param target vec3 The target point
function flightCore:PointTowards(target)
    local roll = self:CalculateRoll()
    local pitch = self:CalculatePitch()
    diag:Info("Roll", roll, "Pith", pitch)
end

function flightCore:ReceiveEvents()
    self.eventHandlerId = system:onEvent("flush", self.Flush, self)
end

function flightCore:StopEvents()
    self:clearEvent("flush", self.eventHandlerId)
end

function flightCore:Flush()
    if self.dirty and self.Ctrl ~= nil then
        self.dirty = false
        self.ctrl.setEngineCommand(self.accelerationGroup:Union(), self.acceleration:unpack(), {0, 0, 0})

        self.ctrl.setEngineCommand(self.rotationGroup:Union(), {0, 0, 0}, self.rotationAcceleration:unpack())
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
