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

local p = 0.01
local i = 2.16
local d = 530
local a = 0.23
local mul = 1

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
        local brakeDistance = brakes:BrakeDistance()
        local velocity = construct.velocity.Movement()
        local reached = behaviour:IsReached()

        -- How far from the travel vector are we?
        local closestPoint = calc.NearestPointOnLine(behaviour.start, behaviour.direction, ownPos)
        local deviationVec = closestPoint - ownPos

        -- Determine if we're moving towards or away from the desired point along the line
        local dev = deviationVec:len()
        local velocityOnPlane = velocity:project_on_plane(direction):normalize_inplace()
        diag:DrawNumber(9, ownPos + velocityOnPlane * 5)
        diag:DrawNumber(0, ownPos + deviationVec:normalize() * 5)

        self.wDeviation:Set(calc.Round(dev, 5))

        local speedControlVec = deviationVec:normalize() * calc.Kph2Mps(3)

        -- How far from the end point are we?
        local distanceVec = behaviour.destination - ownPos
        local distance = distanceVec:len()

        self.wDist:Set(calc.Round(distance, 3))

        speedControlVec = speedControlVec + distanceVec:normalize() * calc.Kph2Mps(behaviour.maxSpeed)
        self.speedCtrlForward:SetVelocity(speedControlVec)
        self.speedCtrlRight:SetVelocity(speedControlVec)
        self.speedCtrlUp:SetVelocity(speedControlVec)

        diag:DrawNumber(1, behaviour.start)
        diag:DrawNumber(2, behaviour.start + (behaviour.destination - behaviour.start) / 2)
        diag:DrawNumber(3, behaviour.destination)

        self.speedCtrlForward:Flush(false)
        self.speedCtrlRight:Flush(false)
        self.speedCtrlUp:Flush(true)

        brakes:Set(0)
    else
        brakes:Set()
    end
end

function moveControl:ActionStart(key)
    if key == "brake" then
        mul = mul * -1
        diag:Info("Mul", mul)
    elseif key == "option4" then
        p = p + 0.01 * mul
    elseif key == "option5" then
        i = i + 0.01 * mul
    elseif key == "option6" then
        d = d + 10 * mul
    elseif key == "option7" then
        a = a + 0.01 * mul
    end

    self.deviationPid = PID(p, i, d, a)
    diag:Info("P", p, ", I:", i, ", D:", d, a)
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
            --system:onEvent("actionStart", singelton.ActionStart, singelton)
            --system:onEvent("actionLoop", singelton.ActionStart, singelton)
            end
            return singelton
        end
    }
)
