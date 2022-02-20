local diag = require("Diagnostics")()
local library = require("abstraction/Library")()
local vec3 = require("builtin/cpml/vec3")
local brakes = require("Brakes")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")
local ctrl = library.GetController()
local engine = require("abstraction/Engine")()
local sharedPanel = require("panel/SharedPanel")()
local PID = require("builtin/cpml/PID")
local min = math.min

local nullVec = vec3()

local moveControl = {}
moveControl.__index = moveControl
local singelton = nil

local function new()
    local instance = {
        deviationPid = PID(0.01, 0.05, 8000),
        distancePid = PID(0.0, 0.00, 0, 0.6),
        queue = {}, -- The positions we want to move to
        minDiff = 0, -- Minimum distance to current point
        wDist = sharedPanel:Get("Move Control"):CreateValue("Dist.", "m"),
        wPid = sharedPanel:Get("Move Control"):CreateValue("PID", "m/s"),
        wDeviation = sharedPanel:Get("Move Control"):CreateValue("Deviation", "m"),
        wQueue = sharedPanel:Get("Move Control"):CreateValue("Points", "")
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
    if #self.queue == 1 then
        self.minDiff = behaviour.margin
    end
end

function moveControl:Flush()
    local behaviour = self:Current()

    if behaviour ~= nil then
        if behaviour:IsReached() then
            local switched
            behaviour, switched = self:Next()
            if switched then
                self.minDiff = behaviour.margin
            end
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

        local dev = deviationVec:len()
        self.deviationPid:inject(dev)
        self.wDeviation:Set(dev)
        local deviationAcceleration = self.deviationPid:get() * deviationVec:normalize()

        ctrl.setEngineCommand(LongLatEngines:Union(), {deviationAcceleration:unpack()})

        -- How far from the end point are we?
        local distanceAlongTravelVector = behaviour.destination - closestPoint
        local distance = distanceAlongTravelVector:len()
        self.distancePid:inject(distance)
        self.minDiff = min(distance, self.minDiff)
        self.wDist:Set(calc.Round(distance, 3) .. " " .. calc.Round(self.minDiff, 3))

        -- Start with an acceleration that counters gravity, if any.
        local acc = -construct.world.GAlongGravity()
        acc = acc + direction * self.distancePid:get()
        if velocity:len() < behaviour.maxSpeed then
            ctrl.setEngineCommand(VerticalEngines:Union(), {acc:unpack()})
        end

        diag:DrawNumber(1, behaviour.start)
        diag:DrawNumber(2, behaviour.start + (behaviour.destination - behaviour.start) / 2)
        diag:DrawNumber(3, behaviour.destination)
        diag:DrawNumber(0, closestPoint)

        if not calc.SameishDirection(direction, velocity) or distance < brakeDistance or reached then
            brakes:Set()
        else
            brakes:Set(0)
        end
    else
        brakes:Set()
    end
end

local p = 0.01
local i = 0.001
local d = 100
local mul = 1
local a = 0.5

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
                system:onEvent("actionStart", singelton.ActionStart, singelton)
                system:onEvent("actionLoop", singelton.ActionStart, singelton)
            end
            return singelton
        end
    }
)
