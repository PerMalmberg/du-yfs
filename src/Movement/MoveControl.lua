local diag = require("Diagnostics")()
local library = require("abstraction/Library")()
local vec3 = require("cpml/vec3")
local brakes = require("Brakes")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")
local ctrl = library.GetController()
local sharedPanel = require("panel/SharedPanel")()
local abs = math.abs

local nullVec = vec3()
local nullTri = {0, 0, 0}

local moveControl = {}
moveControl.__index = moveControl
local singelton = nil

local BRAKE_MARK = "MoveControlBrake"

local function new()
    local instance = {
        queue = {}, -- The positions we want to move to
        wVel = sharedPanel:Get("Move Control"):CreateValue("Vel.", "m/s"),
        wDeviation = sharedPanel:Get("Move Control"):CreateValue("Deviation", "m"),
        wToDest = sharedPanel:Get("Move Control"):CreateValue("To dest", "m"),
        wQueue = sharedPanel:Get("Move Control"):CreateValue("Points", ""),
        wMode = sharedPanel:Get("Move Control"):CreateValue("Mode", ""),
        lastToDest = nil
    }

    setmetatable(instance, moveControl)

    ctrl.setEngineCommand("ALL", nullTri, nullTri)

    return instance
end

function moveControl:Current()
    return self.queue[1]
end

function moveControl:Next()
    local switched = false
    if #self.queue > 1 then
        table.remove(self.queue, 1)
        switched = true
    end

    return self:Current(), switched
end

function moveControl:Clear()
    while #self.queue > 0 do
        table.remove(self.queue, 1)
    end
end

function moveControl:Append(behaviour)
    diag:AssertIsTable(behaviour, "behaviour", "moveControl:Append")

    table.insert(self.queue, #self.queue + 1, behaviour)
end

function moveControl:TimeToTarget()
end

local i = 0

---Returns true if we have moved towards compared to last check.
---@param toDest vec3 Distance to destination as a vec3
---@param margin number Margin in meters
function moveControl:MovedTowards(toDest, margin)
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

function moveControl:Flush()
    --[[
    * Gravity
    * Brake deceleration
    * Engine acceleration
    * Engine deceleration

    * Brake distance
    * Distance to target

    * Time to target
    * Time to stop

    * Current travel direction
    * Desired travel direction

    * Current speed
    * Desired speed

    If not within brake distance
        If not at desired speed
            Accelerate towards desired target
        else if at desired speed
            Maintain speed
        else
            decelerate to desired speed
    else
        descelerate to come to a stop at the desired position.

]]
    local acceleration = nullVec
    local behaviour = self:Current()
    local ownPos = construct.position.Current()

    if behaviour == nil then
        self.wVel:Set("-")
        self.wToDest:Set("-")
        self.wDeviation:Set("-")
        self.wMode:Set("-")
    else
        if behaviour:IsReached() then
            local switched
            behaviour, switched = self:Next()
            if switched then
                self.lastToDest = nil
            end
        end

        local toDest = behaviour.destination - ownPos
        local velocity = construct.velocity.Movement()

        local reached = behaviour:IsReached()
        local distance = toDest:len()
        local speed = velocity:len()

        self.wVel:Set(calc.Round(speed, 2) .. "/" .. calc.Round(behaviour.maxSpeed, 2))
        self.wToDest:Set(toDest:len())

        brakes:SetPart(BRAKE_MARK, false)

        -- How far from the travel vector are we?
        local closestPoint = calc.NearestPointOnLine(behaviour.start, behaviour.direction, ownPos)
        local deviationVec = closestPoint - ownPos
        self.wDeviation:Set(deviationVec:len())

        if reached then
            brakes:SetPart(BRAKE_MARK, true)
            self.wMode:Set("Reached")
            acceleration = (toDest + deviationVec):normalize_inplace() * 0.01
        elseif brakes:BrakeDistance() >= distance then
            brakes:SetPart(BRAKE_MARK, true)
            -- Use engines to brake too if needed
            acceleration = -velocity:normalize() * brakes:AdditionalAccelerationNeededToStop(distance, speed)
            self.wMode:Set("Braking")
        else
            if speed < behaviour.maxSpeed then
                self.wMode:Set("Move")
                acceleration = toDest:normalize_inplace() * 4 -- 1m/s2
            elseif speed > behaviour.maxSpeed * 1.01 then
                brakes:SetPart(BRAKE_MARK, true)
            else
                self.wMode:Set("Maintain")
            end
        end

        acceleration = acceleration + self:CounterDeviation(toDest, deviationVec)

        -- Always counter gravity, so we don't have to think about it in other calculations, i.e. pretend we're in space.
        acceleration = acceleration - construct.world.GAlongGravity()

        diag:DrawNumber(0, construct.position.Current() + acceleration:normalize() * 5)
        diag:DrawNumber(1, behaviour.start)
        diag:DrawNumber(2, behaviour.start + (behaviour.destination - behaviour.start) / 2)
        diag:DrawNumber(3, behaviour.destination)
    end

    self.wQueue:Set(#self.queue)

    ctrl.setEngineCommand("thrust", {acceleration:unpack()})
end

function moveControl:CounterDeviation(toDestination, deviationVec)
    local res = nullVec
    local movedTowards = self:MovedTowards(toDestination, 0.3)
    -- If moving away, enable brakes to counter wrong direction
    if not movedTowards then
        brakes:SetPart(BRAKE_MARK, true)
        res = deviationVec:normalize_inplace() * 0.02 -- 0.02m/s2
    end
    -- Don't turn if off, that's done on each Flush()

    return res
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
