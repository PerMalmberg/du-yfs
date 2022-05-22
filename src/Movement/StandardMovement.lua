local diag = require("Diagnostics")()
local vec3 = require("cpml/vec3")
local construct = require("abstraction/Construct")()
local brakes = require("Brakes")()
local calc = require("Calc")
local PID = require("cpml/PID")
local utils = require("cpml/utils")
local abs = math.abs

local nullVec = vec3()
local BRAKE_MARK = "MoveControlBrake"

local standardMovement = {}
standardMovement.__index = standardMovement

---@param origin vec3 The origin point of travel from
---@param destination vec3 The destination point of travel
---@param yawAndPitch vec3 A function returning the pitch/yaw alignment point
---@param roll vec3 A function returning the point towards which the topside should align
---@param margin number The distance, in meters, the construct must be within the destination for it to be considered reached.
---@param maxSpeed number The maximum speed to travel towards the point, in m/s
local function new(origin, destination, margin, maxSpeed)
    diag:AssertIsVec3(origin, "start", "StandardMovement:new")
    diag:AssertIsVec3(destination, "destination", "StandardMovement:new")
    diag:AssertIsNumber(margin, "margin", "StandardMovement:new")
    diag:AssertIsNumber(maxSpeed, "maxSpeed", "StandardMovement:new")

    local o = {
        origin = origin,
        destination = destination,
        direction = (destination - origin):normalize(),
        margin = margin,
        parallelPathStart = origin + calc.StraightForward(-construct.world.GAlongGravity(), construct.orientation.Right()) * 10, -- 10m infront
        maxSpeed = maxSpeed,
        lastToDest = nil,
        reachStandStill = false,
        pid = PID(0.01, 0.01, 0)
    }

    setmetatable(o, standardMovement)
    return o
end

function standardMovement:YawAndPitch()
    -- Return a point at the same height 10 meters infront to keep us level
    local distanceFromStart = construct.position.Current() - self.origin
    return self.parallelPathStart + distanceFromStart
end

function standardMovement:Roll()
    return construct.position.Current() - construct.world.GAlongGravity():normalize() * 100
end

function standardMovement:IsReached()
    local diff = (self.destination - construct.position.Current()):len()
    return diff <= self.margin
end

function standardMovement:Move(target, modeWidget, deviationVec)
    local ownPos = construct.position.Current()
    local toDest = target - ownPos
    local distance = toDest:len()
    local velocity = construct.velocity.Movement()
    local speed = velocity:len()

    local reached = self:IsReached()

    local acceleration = nullVec

    local mode

    -- 1 fully aligned, 0 not aligned to destination
    local travelAlignment = utils.clamp(velocity:normalize():dot(toDest:normalize()), 0, 1)

    if brakes:BrakeDistance() >= distance or speed >= self.maxSpeed * 1.01 then
        brakes:SetPart(BRAKE_MARK, true)
        -- Use engines to brake too if needed
        acceleration = -velocity:normalize() * brakes:AdditionalAccelerationNeededToStop(distance, speed)
        mode = "Braking"
    elseif travelAlignment < 0.85 then
        brakes:SetPart(BRAKE_MARK, true)
        mode = "Deviating"
    else
        mode = "Accelerating"
    end

    modeWidget:Set(mode .. " " .. tostring(travelAlignment))

    self.pid:inject(deviationVec:len())

    if acceleration == nullVec then
        acceleration = toDest:normalize() * (1 + 5 * (1 - travelAlignment))
        -- Don't let deviation adustment take overhand so clamp it.
        local devAcc = deviationVec:normalize_inplace() * utils.clamp(self.pid:get(), 0, 0.2)
        acceleration = acceleration + devAcc
    end

    return acceleration
end

---Returns true if we have moved towards target compared to last check.
---@param toDest vec3 Distance to destination as a vec3
---@param margin number Margin in meters
function standardMovement:MovedTowards(toDest, margin)
    local res = true

    if self.lastToDest == nil then
        self.lastToDest = toDest
    elseif (self.lastToDest - toDest):len() > margin then
        -- Must check each axis separately since vector:len() can become less without
        -- us actually moving *towards* the destination; we might be moving up to the target, but on path beside it.
        res = abs(toDest.x) <= abs(self.lastToDest.x) and abs(toDest.y) <= abs(self.lastToDest.y) and abs(toDest.z) <= abs(self.lastToDest.z)
        self.lastToDest = toDest
    end

    return res
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
