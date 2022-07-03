local brakes = require("flight/Brakes")()
local vehicle = require("du-libs:abstraction/Vehicle")()
local calc = require("du-libs:util/Calc")
local ctrl = require("du-libs:abstraction/Library")():GetController()
local Enum = require("du-libs:util/Enum")
local visual = require("du-libs:debug/Visual")()
local nullVec = require("cpml/vec3")()
local sharedPanel = require("du-libs:panel/SharedPanel")()
local log = require("du-libs:debug/Log")()
local universe = require("du-libs:universe/Universe")()
local EngineGroup = require("du-libs:abstraction/EngineGroup")
local PID = require("cpml/pid")
require("flight/state/Require")
local CurrentPos = vehicle.position.Current
local Velocity = vehicle.velocity.Movement

local FlightMode = Enum {
    "AXIS",
    "FREE"
}

local longitudinal = "longitudinal"
local vertical = "vertical"
local lateral = "lateral"
local airfoil = "airfoil"
local thrustTag = "thrust"
local Forward = vehicle.orientation.Forward
local Right = vehicle.orientation.Right
local AntiG = function()
    return -universe:VerticalReferenceVector() * vehicle.world.G()
end
local NoAntiG = function()
    return nullVec
end

local forwardGroup = {
    thrust = { engines = EngineGroup(longitudinal),
               prio1Tag = thrustTag,
               prio2Tag = "",
               prio3Tag = "",
               antiG = NoAntiG
    },
    adjust = { engines = EngineGroup(airfoil, lateral, vertical),
               prio1Tag = airfoil,
               prio2Tag = lateral,
               prio3Tag = vertical,
               antiG = AntiG
    }
}

local rightGroup = {
    thrust = { engines = EngineGroup(lateral),
               prio1Tag = thrustTag,
               prio2Tag = "",
               prio3Tag = "",
               antiG = NoAntiG
    },
    adjust = { engines = EngineGroup(vertical, longitudinal),
               prio1Tag = vertical,
               prio2Tag = longitudinal,
               prio3Tag = "",
               antiG = AntiG
    }
}

local upGroup = {
    thrust = { engines = EngineGroup(vertical),
               prio1Tag = vertical,
               prio2Tag = "",
               prio3Tag = "",
               antiG = AntiG
    },
    adjust = { engines = EngineGroup(lateral, longitudinal),
               prio1Tag = vertical,
               prio2Tag = longitudinal,
               prio3Tag = "",
               antiG = NoAntiG
    }
}

local fsm = {}
fsm.__index = fsm

local function new()
    local instance = {
        current = nil,
        wStateName = sharedPanel:Get("FlightFSM"):CreateValue("State", ""),
        wDeviation = sharedPanel:Get("FlightFSM"):CreateValue("Deviation", "m"),
        wAcceleration = sharedPanel:Get("FlightFSM"):CreateValue("Acceleration", "m/s2"),
        nearestPoint = nil,
        acceleration = nil,
        adjustAcc = nullVec,
        -- Use a low amortization to quickly stop adjusting
        deviationPID = PID(0, 1, 5, 0.4),
        mode = FlightMode.AXIS
    }

    setmetatable(instance, fsm)
    instance:SetState(Idle(instance))
    return instance
end

function fsm:GetEngines(moveDirection)
    if moveDirection:dot(Forward()) >= 0.707 then
        return forwardGroup
    elseif moveDirection:dot(Right()) >= 0.707 then
        return rightGroup
    else
        return upGroup
    end
end

function fsm:CheckPathAlignment(currentPos, chaseData)
    local res = true

    if self.mode == FlightMode.AXIS then
        local travelDir = Velocity():normalize_inplace()
        local speed = Velocity():len()

        local toRabbit = chaseData.rabbit - currentPos
        local toNearest = chaseData.nearest - currentPos

        local tolerance = 0.85
        if speed > 1 then
            res = travelDir:dot(toRabbit:normalize()) >= tolerance or travelDir:dot(toNearest:normalize()) >= tolerance
        end
    end

    return res
end

function fsm:FsmFlush(next, previous)

    local pos = CurrentPos()

    local c = self.current
    if c ~= nil then
        local chaseData = self:NearestPointBetweenWaypoints(previous, next, pos, 6)

        brakes:Set(false)

        -- Are we moving in the desired direction?
        if not self:CheckPathAlignment(pos, chaseData) then
            self:SetState(CorrectDeviation(self))
        end

        self.acceleration = nullVec
        self.adjustAcc = nullVec

        c:Flush(next, previous, chaseData)
        self:AdjustForDeviation(chaseData, pos, next.margin)

        self:ApplyAcceleration(next:DirectionTo())

        visual:DrawNumber(9, chaseData.rabbit)
        visual:DrawNumber(8, chaseData.nearest)
        visual:DrawNumber(0, pos + self.acceleration:normalize() * 8)
    else
        self:ApplyAcceleration(nullVec)
    end

end

function fsm:AdjustForDeviation(chaseData, currentPos, margin)
    -- Add counter to deviation from optimal path
    local nearDeviation = chaseData.nearest - currentPos
    local len = nearDeviation:len()
    self.deviationPID:inject(len)
    self.wDeviation:Set(calc.Round(len, 4))

    local maxDeviationAcc = 5

    if nearDeviation:len() > margin / 2 then
        self.adjustAcc = nearDeviation:normalize() * utils.clamp(self.deviationPID:get(), 0.0, maxDeviationAcc)
    else
        self.adjustAcc = nullVec
    end
end

function fsm:ApplyAcceleration(moveDirection)
    if self.acceleration ~= nil then
        local groups = self:GetEngines(moveDirection)
        local t = groups.thrust
        local a = groups.adjust
        local thrustAcc = (self.acceleration or nullVec) + t.antiG()
        local adjustAcc = (self.adjustAcc or nullVec) + a.antiG()

        ctrl.setEngineCommand(t.engines:Intersection(), { thrustAcc:unpack() }, { 0, 0, 0 }, 0, 0, t.prio1Tag, t.prio2Tag, t.prio3Tag, 0.001)
        if adjustAcc:len2() == 0 then
            ctrl.setEngineThrust(a.engines:Union(), 1000)
        else
            ctrl.setEngineCommand(a.engines:Union(), { adjustAcc:unpack() }, { 0, 0, 0 }, 0, 0, a.prio1Tag, a.prio2Tag, a.prio3Tag, 0.001)
        end
    else
        ctrl.setEngineCommand("all", { 0, 0, 0 }, { 0, 0, 0 }, 0, 0, "", "", "", 0.001)
    end
end

function fsm:Update()
    local c = self.current
    if c ~= nil then
        self.wAcceleration:Set(calc.Round(Velocity():len(), 2))
        c:Update()
    end
end

function fsm:WaypointReached(isLastWaypoint, next, previous)
    if self.current ~= nil then
        self.current:WaypointReached(isLastWaypoint, next, previous)
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

function fsm:SetFreeMode()
    self.mode = FlightMode.FREE
    log:Info("Free mode")
end

function fsm:SetAxisMode()
    self.mode = FlightMode.AXIS
    log:Info("Axis mode")
end

function fsm:DisableThrust()
    self.acceleration = nil
    self.adjustAcc = nil
end

function fsm:Thrust(acceleration, adjustAcc)
    self.acceleration = acceleration or nullVec
    self.adjustAcc = adjustAcc or nullVec
end

function fsm:NullThrust()
    self.acceleration = nullVec
    self.adjustAcc = nullVec
end

function fsm:NearestPointBetweenWaypoints(wpStart, wpEnd, currentPos, ahead)
    local totalDiff = wpEnd.destination - wpStart.destination
    local dir = totalDiff:normalize()
    local nearestPoint = calc.NearestPointOnLine(wpStart.destination, dir, currentPos)

    ahead = (ahead or 0)
    local point = nearestPoint + dir * ahead
    local remaining = wpEnd.destination - point

    -- Is the point past the end (remaining points back towards start or we're very close to the destination)?
    if remaining:normalize():dot(dir) < 1 or remaining:len() < 0.01 then
        return { rabbit = wpEnd.destination, nearest = nearestPoint }
    else
        return { rabbit = point, nearest = nearestPoint }
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