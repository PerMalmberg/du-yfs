local diag = require("Diagnostics")()
local library = require("abstraction/Library")()
local vec3 = require("builtin/cpml/vec3")
local brakes = require("Brakes")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")
local ctrl = library.GetController()
local engine = require("abstraction/Engine")()

local nullVec = vec3()

local moveControl = {}
moveControl.__index = moveControl
local singelton = nil

local function new()
    local instance = {
        behaviour = {}, -- The positions we want to move to
        last = nil -- The last position, to return when there are no more to move to.
    }

    setmetatable(instance, moveControl)

    return instance
end

function moveControl:Current()
    return self.behaviour[1] or self.last
end

function moveControl:Next()
    if #self > 0 then
        table.remove(self.behaviour, 1)
    end

    return self:Current()
end

function moveControl:Clear()
    while #self.behaviour > 0 do
        table.remove(self.behaviour, 1)
    end
end

function moveControl:Append(behaviour)
    diag:AssertIsTable(behaviour, "behaviour", "moveControl:Append")
    table.insert(self.behaviour, #self.behaviour + 1, behaviour)
    self.last = behaviour
end

function moveControl:Flush()
    local behaviour = self:Current()

    if behaviour ~= nil then
        if behaviour:IsReached() then
            behaviour = self:Next()
        end
    end

    local acc = nullVec

    if behaviour ~= nil then
        local distanceToDestination = behaviour.destination - construct.position.Current()
        local direction = distanceToDestination:normalize()
        local brakeDistance = brakes:BrakeDistance()
        local velocity = construct.velocity.Movement()
        local reached = behaviour:IsReached()

        local enableBrakes = false

        if not calc.SameishDirection(direction, velocity) or distanceToDestination:len() < brakeDistance then
            enableBrakes = true
        end

        acc = -construct.world.GAlongGravity()

        if (velocity:len() < behaviour.maxSpeed) and not reached then
            acc = acc + direction * 10
        end

        if enableBrakes or reached then
            brakes:Set()
        else
            brakes:Set(0)
        end
    else
        brakes:Set()
    end

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
