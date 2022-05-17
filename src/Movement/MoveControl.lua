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
        wQueue = sharedPanel:Get("Move Control"):CreateValue("Points", ""),
        wMode = sharedPanel:Get("Move Control"):CreateValue("Mode", ""),
        wVel = sharedPanel:Get("Move Control"):CreateValue("Vel.", "m/s"),
        wDeviation = sharedPanel:Get("Move Control"):CreateValue("Deviation", "m"),
        wToDest = sharedPanel:Get("Move Control"):CreateValue("To dest", "m")
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

function moveControl:Append(movement)
    diag:AssertIsTable(movement, "movement", "moveControl:Append")

    table.insert(self.queue, #self.queue + 1, movement)
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
    local movement = self:Current()

    if movement == nil then
        self.wVel:Set("-")
        self.wToDest:Set("-")
        self.wDeviation:Set("-")
        self.wMode:Set("-")
    else
        if movement:IsReached() then
            local switched
            movement, switched = self:Next()
            if switched then
                self.lastToDest = nil
            end
        end

        self.wVel:Set(calc.Round(construct.velocity.Movement():len(), 2) .. "/" .. calc.Round(movement.maxSpeed, 2))
        local currentPos = construct.position.Current()
        self.wToDest:Set((movement.destination - currentPos):len())

        brakes:SetPart(BRAKE_MARK, false)

        -- How far from the travel vector are we?
        local closestPoint = calc.NearestPointOnLine(movement.origin, movement.direction, currentPos)
        local deviationVec = closestPoint - currentPos
        self.wDeviation:Set(calc.Round(deviationVec:len(), 5))

        acceleration = movement:Move(self.wMode, deviationVec)

        diag:DrawNumber(0, construct.position.Current() + acceleration:normalize() * 5)
        diag:DrawNumber(1, movement.origin)
        diag:DrawNumber(2, movement.origin + (movement.destination - movement.origin) / 2)
        diag:DrawNumber(3, movement.destination)
        diag:DrawNumber(9, closestPoint)
    end

    self.wQueue:Set(#self.queue)

    -- Always counter gravity if some command has been given,
    -- so we don't have to think about it in other calculations, i.e. pretend we're in space.
    if acceleration:len2() > 0 then
        acceleration = acceleration - construct.world.GAlongGravity()
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
