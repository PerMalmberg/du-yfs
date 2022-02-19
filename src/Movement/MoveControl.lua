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
        pid = PID(0.001, 0.50, 8000, 0.6),
        queue = {}, -- The positions we want to move to
        last = nil, -- The last position, to return when there are no more to move to.
        minDiff = 0, -- Minimum distance to current point
        wAcc = sharedPanel:Get("Move Control"):CreateValue("Acc.", "m/s2"),
        wDist = sharedPanel:Get("Move Control"):CreateValue("Dist.", "m"),
        wPid = sharedPanel:Get("Move Control"):CreateValue("PID", "m/s"),
        wQueue = sharedPanel:Get("Move Control"):CreateValue("Points", "")
    }

    setmetatable(instance, moveControl)

    return instance
end

function moveControl:Current()
    return self.queue[1] or self.last
end

function moveControl:Next()
    local switched = false
    if #self.queue > 0 then
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

    local curr = self:Current()

    table.insert(self.queue, #self.queue + 1, behaviour)
    if #self.queue == 1 then
        self.minDiff = behaviour.margin
    end

    self.last = behaviour
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

    local acc = nullVec

    if behaviour ~= nil then
        local toDest = behaviour.destination - construct.position.Current()
        local direction = toDest:normalize()
        local distanceToDestination = toDest:len()
        local brakeDistance = brakes:BrakeDistance()
        local velocity = construct.velocity.Movement()
        local reached = behaviour:IsReached()

        self.minDiff = min(distanceToDestination, self.minDiff)
        self.wDist:Set(calc.Round(distanceToDestination, 3) .. " " .. calc.Round(self.minDiff, 3))

        diag:DrawNumber(1, behaviour.destination)

        self.pid:inject(distanceToDestination)
        local pidValue = self.pid:get()
        local maxSpeed = min(pidValue, behaviour.maxSpeed)
        self.wPid:Set(pidValue .. " (" .. maxSpeed .. ")")

        local enableBrakes = false

        if not calc.SameishDirection(direction, velocity) or distanceToDestination < brakeDistance then
            enableBrakes = true
        end

        -- Start with an acceleration that counters gravity, if any.
        acc = -construct.world.GAlongGravity()

        if velocity:len() < maxSpeed then
            acc = acc + direction * construct.world.G() * 1.01
        end

        if enableBrakes or reached then
            brakes:Set()
        else
            brakes:Set(0)
        end
    else
        brakes:Set()
    end

    self.wAcc:Set(acc:len())

    ctrl.setEngineCommand(ThrustEngines:Union(), {acc:unpack()})
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
