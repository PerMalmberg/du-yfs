local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local vec3 = require("cpml/vec3")
local construct = require("abstraction/Construct")()
local ctrl = library.GetController()
local PID = require("cpml/pid")
local Engine = require("abstraction/Engine")

local speedControl = {}
speedControl.__index = speedControl

SpeedControlUp = 1
SpeedControlForward = 2
SpeedControlRight = 3
local finalAcceleration = {}
local Velocity = construct.velocity.Movement

local function new(controlledAxis)
    diag:AssertIsNumber(controlledAxis, "controlledAxis", "speedControl:new")

    local instance = {
        controlledAxis = controlledAxis, -- Getter for the normal vector of the plane this instance is working on.
        targetVelocity = vec3(), -- The target speed and direction
        pid = PID(0.01, 0.001, 0)
    }

    setmetatable(instance, speedControl)

    return instance
end

function speedControl:SetVelocity(vel)
    diag:AssertIsVec3(vel, "vel", "speedControl:SetVelocity")
    self.targetVelocity = vel
end

function speedControl:Normal()
    if self.controlledAxis == SpeedControlUp then
        return construct.orientation.Up()
    elseif self.controlledAxis == SpeedControlForward then
        return construct.orientation.Forward()
    else
        return construct.orientation.Right()
    end
end

function speedControl:Flush(apply)
    local normal = self:Normal()
    local velocityOnPlane = Velocity():project_on_plane(normal)
    local directionOnPlane = self.targetVelocity:project_on_plane(normal)

    -- Get the current speed difference. If moving away, we get a negative value meaning the error becomes larger.
    local currentSpeedOnPlane = velocityOnPlane:dot(directionOnPlane) * Velocity():len()
    local targetSpeedOnPlane = directionOnPlane:len()

    local speedError = targetSpeedOnPlane - currentSpeedOnPlane
    self.pid:inject(speedError)

    finalAcceleration[self.controlledAxis] = self.pid:get() * directionOnPlane:normalize()

    if apply then
        local total = finalAcceleration[SpeedControlUp] + finalAcceleration[SpeedControlForward] + finalAcceleration[SpeedControlRight]
        total = total - construct.world.GAlongGravity()
        ctrl.setEngineCommand(ThrustEngines:Union(), {total:unpack()})
    end
end

-- The module
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
