local diag = require("Diagnostics")()
local library = require("abstraction/Library")()
local vec3 = require("cpml/vec3")
local brakes = require("Brakes")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")
local ctrl = library.GetController()
local sharedPanel = require("panel/SharedPanel")()

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
        wMode = sharedPanel:Get("Move Control"):CreateValue("Mode", "")
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

function moveControl:Flush()
    local behaviour = self:Current()

    if behaviour ~= nil then
        if behaviour:IsReached() then
            local switched
            behaviour, switched = self:Next()
        end
    end

    self.wQueue:Set(#self.queue)

    if behaviour ~= nil then
        local ownPos = construct.position.Current()
        local toDest = behaviour.destination - ownPos
        local velocity = construct.velocity.Movement()

        local reached = behaviour:IsReached()

        -- How far from the travel vector are we?
        local closestPoint = calc.NearestPointOnLine(behaviour.start, behaviour.direction, ownPos)
        local deviationVec = closestPoint - ownPos

        -- Counter gravity
        local acc = -construct.world.GAlongGravity()

        -- Assume reached
        brakes:SetPart(BRAKE_MARK, true)

        if not reached then
            brakes:SetPart(BRAKE_MARK, false)

            local brakeDistance, validBrake = brakes:BrakeDistance()

            if validBrake and brakeDistance >= toDest:len() then
                brakes:SetPart(BRAKE_MARK, true)
                self.wMode:Set("Braking")
            else
                self.wMode:Set("Moving")

                local direction = deviationVec:normalize() + toDest:normalize()
                direction:normalize_inplace()

                acc = acc + direction
            end
        end

        ctrl.setEngineCommand("thrust", {acc:unpack()})

        self.wVel:Set(velocity:len())
        self.wToDest:Set(toDest:len())
        self.wDeviation:Set(deviationVec:len())

        diag:DrawNumber(1, behaviour.start)
        diag:DrawNumber(2, behaviour.start + (behaviour.destination - behaviour.start) / 2)
        diag:DrawNumber(3, behaviour.destination)
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
