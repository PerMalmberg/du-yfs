local diag = require("Diagnostics")()
local vec3 = require("cpml/vec3")
local construct = require("abstraction/Construct")()
local brakes = require("Brakes")()
local calc = require("Calc")
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
        reachStandStill = false
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
    local velocity = construct.velocity.Movement()

    local reached = self:IsReached()
    local distance = toDest:len()
    local speed = velocity:len()

    brakes:SetPart(BRAKE_MARK, false)

    local acceleration = nullVec

    if reached then
        brakes:SetPart(BRAKE_MARK, true)
        modeWidget:Set("Reached")
    elseif brakes:BrakeDistance() >= distance then
        brakes:SetPart(BRAKE_MARK, true)
        -- Use engines to brake too if needed
        acceleration = -velocity:normalize() * brakes:AdditionalAccelerationNeededToStop(distance, speed)
        modeWidget:Set("Braking")
    else
        local acc = 1
        if self.reachStandStill then
            acc = 0.1
        end

        if speed < self.maxSpeed then
            modeWidget:Set("Accelerate")
            acceleration = toDest:normalize() * acc -- m/s2
        elseif speed > self.maxSpeed * 1.01 then
            modeWidget:Set("Decelerate")
            brakes:SetPart(BRAKE_MARK, true)
            acceleration = toDest:normalize() * acc -- m/s2 -- QQQ Is it good to accelerate while braking? Can we do otherwise and stil move in the desired direction?
        else
            modeWidget:Set("Maintain")
        end
    end

    acceleration = acceleration + self:CounterDeviation(toDest, deviationVec)

    return acceleration
end

function standardMovement:CounterDeviation(toDestination, deviationVec, margin)
    -- If moving away, enable brakes to counter wrong direction
    if not self:MovedTowards(toDestination, 0.2) then
        brakes:SetPart(BRAKE_MARK, true)
    end
    -- Don't turn off brakes, that's done by MoveControl

    if deviationVec:len() > 0.001 then
        return deviationVec:normalize_inplace() * 0.02 -- 0.02m/s2
    else
        return nullVec
    end
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
