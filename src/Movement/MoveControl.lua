local diag = require("Diagnostics")
local Brakes = require("Brakes")
local construct = require("abstraction/Construct")

local moveControl = {}
moveControl.__index = moveControl

local function new()
    local instance = {
        behaviour = {}, -- The positions we want to move to
        last = nil, -- The last position, to return when there are no more to move to.
        brakes = Brakes()
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

    if behaviour ~= nil then
        local distanceToDestination = behaviour.destination - construct.position.Current()
        local direction = distanceToDestination:normalize()
    end
end

-- The module
return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            return new()
        end
    }
)
