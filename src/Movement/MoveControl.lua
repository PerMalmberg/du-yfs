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

local BRAKE_MARK = "MoveControlReached"

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
function moveControl:MovedTowards(toDest)
    local res = true

    if self.lastToDest ~= nil then
        -- Must check each axis separately since vector:len() can become less without
        -- us actually moving *towards* the destination; we might be moving up to the target, but on path beside it.
        res = abs(toDest.x) <= abs(self.lastToDest.x) and abs(toDest.y) <= abs(self.lastToDest.y) and abs(toDest.z) <= abs(self.lastToDest.z)
    end

    self.lastToDest = toDest

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
    local toDest = nullVec

    if behaviour ~= nil then
        if behaviour:IsReached() then
            local switched
            behaviour, switched = self:Next()
            if switched then
                self.lastToDest = nil
            end
        end
    end

    self.wQueue:Set(#self.queue)

    if behaviour ~= nil then
        toDest = behaviour.destination - ownPos
        local velocity = construct.velocity.Movement()

        local reached = behaviour:IsReached()
        local distance = toDest:len()
        local speed = velocity:len()

        brakes:SetPart(BRAKE_MARK, false, "A")

        -- How far from the travel vector are we?
        local closestPoint = calc.NearestPointOnLine(behaviour.start, behaviour.direction, ownPos)
        local deviationVec = closestPoint - ownPos

        if reached then
            brakes:SetPart(BRAKE_MARK, true, "B")
            self.wMode:Set("Reached")
        elseif brakes:BrakeDistance() >= distance then
            brakes:SetPart(BRAKE_MARK, true, "C")
            -- Use engines to brake too if needed
            acceleration = -velocity:normalize() * brakes:AdditionalAccelerationNeededToStop(distance, speed)
            self.wMode:Set("Braking")
        else
            local movedTowards = self:MovedTowards(toDest)
            if not movedTowards or speed < behaviour.maxSpeed then
                -- If moving away, enable brakes to counter wrong direction
                brakes:SetPart(BRAKE_MARK, not movedTowards, "D")
                self.wMode:Set("Move, acc")
                acceleration = (toDest + deviationVec):normalize_inplace() -- 1g
            else
                self.wMode:Set("Maintain")
            end
        end

        -- Always counter gravity, so we don't have to think about it in other calculations, i.e. pretend we're in space.
        acceleration = acceleration - construct.world.GAlongGravity()

        self.wVel:Set(velocity:len())
        self.wToDest:Set(toDest:len())
        self.wDeviation:Set(deviationVec:len())

        diag:DrawNumber(0, construct.position.Current() + acceleration:normalize() * 5)
        diag:DrawNumber(1, behaviour.start)
        diag:DrawNumber(2, behaviour.start + (behaviour.destination - behaviour.start) / 2)
        diag:DrawNumber(3, behaviour.destination)
    end

    ctrl.setEngineCommand("thrust", {acceleration:unpack()})
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
