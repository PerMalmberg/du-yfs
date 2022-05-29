local Idle = require("movement/state/Idle")
local sharedPanel = require("panel/SharedPanel")()
local construct = require("abstraction/Construct")()
local library = require("abstraction/Library")()
local calc = require("Calc")
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

function fsm:Flush(waypoint, previousWaypoint)
    self.nearestPoint = self:NearestPointBetweenWaypoints(waypoint, previousWaypoint, construct.position.Current())

    local c = self.current
    if c ~= nil then
        c:Flush(waypoint, previousWaypoint)
    end
end

function fsm:Update()
    local c = self.current
    if c ~= nil then
        c:Update()
    end
end

function fsm:SetState(state)
    local old = self.current
    if old ~= nil then
        old:Leave()
    end

    if state ~= nil then
        self.current = state
        state:Enter()
        self.wStateName:Set(state:Name())
    end
end

function fsm:Thrust(acceleration)
    -- Compensate for any gravity
    acceleration = acceleration - construct.world.GAlongGravity()
    ctrl.setEngineCommand("thrust", { acceleration:unpack() })
end

function fsm:NullThrust()
    ctrl.setEngineCommand("thrust", { 0, 0, 0 })
end

function fsm:NearestPointBetweenWaypoints(wpStart, wpEnd, currentPos, ahead)
    ahead = ahead or 0
    local diff = wpEnd.destination - wpStart.destination
    local dirToEnd = diff:normalize()
    local nearestPoint = calc.NearestPointOnLine(wpStart.destination, dirToEnd, currentPos)
    local diffToEnd = nearestPoint - wpEnd.destination
    -- Is the point past the end?
    if diffToEnd:len() + ahead > diff:len() then
        return wpEnd.destination
    else
        return nearestPoint + ahead
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