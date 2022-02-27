local diag = require("Diagnostics")()
local library = require("abstraction/Library")()
local vec3 = require("cpml/vec3")
local brakes = require("Brakes")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")
local ctrl = library.GetController()
local engine = require("abstraction/Engine")()
local sharedPanel = require("panel/SharedPanel")()
local PID = require("cpml/PID")
local SpeedControl = require("movement/SpeedControl")
local min = math.min

local nullVec = vec3()
local nullTri = {0, 0, 0}

local moveControl = {}
moveControl.__index = moveControl
local singelton = nil

local BRAKE_MARK = "MoveControlReached"

local function new()
    local instance = {
        queue = {}, -- The positions we want to move to
        wDist = sharedPanel:Get("Move Control"):CreateValue("Dist.", "m"),
        wDeviation = sharedPanel:Get("Move Control"):CreateValue("Deviation", "m"),
        wQueue = sharedPanel:Get("Move Control"):CreateValue("Points", ""),
        speedCtrlForward = SpeedControl(SpeedControlForward),
        speedCtrlRight = SpeedControl(SpeedControlRight),
        speedCtrlUp = SpeedControl(SpeedControlUp)
    }

    setmetatable(instance, moveControl)

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
        local direction = toDest:normalize()
        local velocity = construct.velocity.Movement()
        local reached = behaviour:IsReached()

        local speedControlVec = nullVec

        if reached then
            local g = construct.world.GAlongGravity()
            if g:len2() > 0 then
                brakes:SetPart(BRAKE_MARK, -g)
            else
                brakes:SetPart(BRAKE_MARK, -velocity:normalize())
            end
        else
            brakes:SetPart(BRAKE_MARK, nullVec)

            -- How far from the travel vector are we?
            local closestPoint = calc.NearestPointOnLine(behaviour.start, behaviour.direction, ownPos)
            local deviationVec = closestPoint - ownPos

            local velocityOnPlane = velocity:project_on_plane(direction):normalize_inplace()
            diag:DrawNumber(9, ownPos + velocityOnPlane * 5)
            diag:DrawNumber(0, ownPos + deviationVec:normalize() * 5)

            self.wDeviation:Set(calc.Round(deviationVec:len(), 5))

            speedControlVec = deviationVec:normalize() * behaviour.maxSpeed

            -- How far from the end point are we?
            local distanceVec = behaviour.destination - ownPos
            local distance = distanceVec:len()

            self.wDist:Set(calc.Round(distance, 3))

            local brakeDistance = brakes:BrakeDistance()
            if brakeDistance >= distance then
                brakes:SetPart(BRAKE_MARK, -velocity:normalize())
            else
                brakes:SetPart(BRAKE_MARK, nullVec)
                speedControlVec = speedControlVec + distanceVec:normalize() * behaviour.maxSpeed
            end

            diag:DrawNumber(1, behaviour.start)
            diag:DrawNumber(2, behaviour.start + (behaviour.destination - behaviour.start) / 2)
            diag:DrawNumber(3, behaviour.destination)
        end

        self.speedCtrlForward:SetVelocity(speedControlVec)
        self.speedCtrlRight:SetVelocity(speedControlVec)
        self.speedCtrlUp:SetVelocity(speedControlVec)

        self.speedCtrlForward:Flush(false)
        self.speedCtrlRight:Flush(false)
        self.speedCtrlUp:Flush(true)
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
