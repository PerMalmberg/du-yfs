require("movement/state/Require")
local sharedPanel = require("panel/SharedPanel")()
local construct = require("abstraction/Construct")()
local library = require("abstraction/Library")()
local calc = require("Calc")
local nullVec = require("cpml/vec3")()
local diag = require("Diagnostics")()
local ctrl = library.GetController()

local fsm = {}
fsm.__index = fsm

local function new()
    local instance = {
        current = nil,
        wStateName = sharedPanel:Get("FlightFSM"):CreateValue("State", ""),
        nearestPoint = nil
    }
    setmetatable(instance, fsm)
    instance:SetState(Idle(instance))
    return instance
end

function fsm:Flush(next, previous)
    local c = self.current
    if c ~= nil then
        c:Flush(next, previous)
    end
end

function fsm:Update()
    local c = self.current
    if c ~= nil then
        c:Update()
    end
end

function fsm:SetState(state)
    if self.current ~= nil then
        self.current:Leave()
    end

    if state == nil then
        self.wStateName:Set("No state!")
    else
        self.wStateName:Set(state:Name())
        state:Enter()
    end

    self.current = state
end

function fsm:Thrust(acceleration)
    acceleration = acceleration or nullVec
    -- Compensate for any gravity
    acceleration = acceleration - construct.world.GAlongGravity()
    ctrl.setEngineCommand("thrust", { acceleration:unpack() })
end

function fsm:NullThrust()
    ctrl.setEngineCommand("thrust", { 0, 0, 0 })
end

function fsm:NearestPointBetweenWaypoints(wpStart, wpEnd, currentPos, ahead)
    local totalDiff = wpEnd.destination - wpStart.destination
    local dir = totalDiff:normalize()
    local nearestPoint = calc.NearestPointOnLine(wpStart.destination, dir, currentPos)
    local remaining = wpEnd.destination - nearestPoint


    -- Is the point past the end (remaining points back towards start or we're very close to the destination)?
    if remaining:normalize():dot(dir) < 0 or remaining:len() < 0.01 then
        return wpEnd.destination
    else
        -- Room to spare the extra?
        ahead = (ahead or 0)
        if remaining:len() > ahead then
            nearestPoint = nearestPoint + dir * ahead
        end

        return nearestPoint
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