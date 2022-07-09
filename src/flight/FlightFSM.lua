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
local Vec3 = require("cpml/vec3")
require("flight/state/Require")
local CurrentPos = vehicle.position.Current
local Velocity = vehicle.velocity.Movement
local abs = math.abs

local FlightMode = Enum {
    "PRECISION",
    "NORMAL"
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

local normalModeGroup = {
    thrust = {
        engines = EngineGroup(thrustTag, airfoil),
        prio1Tag = airfoil,
        prio2Tag = thrustTag,
        prio3Tag = "",
        antiG = AntiG
    },
    adjust = { engines = EngineGroup(),
               prio1Tag = "",
               prio2Tag = "",
               prio3Tag = "",
               antiG = NoAntiG
    }
}

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
        wDevAcceleration = sharedPanel:Get("FlightFSM"):CreateValue("Dev. acc.", "m/s2"),
        wAcceleration = sharedPanel:Get("FlightFSM"):CreateValue("Acceleration", "m/s2"),
        nearestPoint = nil,
        acceleration = nil,
        adjustAcc = nullVec,
        -- Use a low amortization to quickly stop adjusting
        deviationPID = PID(0, 1, 5, 0.2),
        mode = FlightMode.PRECISION
    }

    setmetatable(instance, fsm)
    instance:SetState(Idle(instance))
    return instance
end

function fsm:GetEngines(moveDirection)
    if self.mode == FlightMode.PRECISION then
        if abs(moveDirection:dot(Forward())) >= 0.707 then
            return forwardGroup
        elseif abs(moveDirection:dot(Right())) >= 0.707 then
            return rightGroup
        else
            return upGroup
        end
    else
        return normalModeGroup
    end
end

function fsm:CheckPathAlignment(currentPos, chaseData)
    local res = true

    local toleranceDistance = 3 -- meters
    local toleranceDirection = 0.85

    local vel = Velocity()
    local dir = vel:normalize()
    local speed = vel:len()

    local toNearest = chaseData.nearest - currentPos
    local toRabbit = chaseData.rabbit - currentPos

    if speed > 1 then
        res = toNearest:len() < toleranceDistance and dir:dot(toRabbit:normalize()) >= toleranceDirection
    end

    return res
end

function fsm:FsmFlush(next, previous)

    local pos = CurrentPos()

    local c = self.current
    if c ~= nil then
        local chaseData = self:NearestPointBetweenWaypoints(previous, next, pos, 6)

        brakes:Set(false)

        self.acceleration = nullVec
        self.adjustAcc = nullVec

        c:Flush(next, previous, chaseData)
        self:AdjustForDeviation(chaseData, pos)

        self:ApplyAcceleration(next:DirectionTo())

        visual:DrawNumber(9, chaseData.rabbit)
        visual:DrawNumber(8, chaseData.nearest)
        visual:DrawNumber(0, pos + self.acceleration:normalize() * 8)
    else
        self:ApplyAcceleration(nullVec)
    end
end

function fsm:AdjustForDeviation(chaseData, currentPos)
    -- Add counter to deviation from optimal path
    local nearDeviation = chaseData.nearest - currentPos
    local len = nearDeviation:len()
    self.deviationPID:inject(len)
    self.wDeviation:Set(calc.Round(len, 4))

    local devAcc = vehicle.acceleration.Movement():dot(nearDeviation)
    self.wDevAcceleration:Set(calc.Round(devAcc, 2))

    local maxDeviationAcc = 5
    self.adjustAcc = nearDeviation:normalize() * utils.clamp(self.deviationPID:get(), 0.0, maxDeviationAcc)
end

function fsm:ApplyAcceleration(moveDirection)
    if self.acceleration ~= nil then
        local groups = self:GetEngines(moveDirection)
        local t = groups.thrust
        local a = groups.adjust
        local thrustAcc = (self.acceleration or nullVec) + t.antiG() - Vec3(construct.getWorldAirFrictionAcceleration())
        local adjustAcc = (self.adjustAcc or nullVec) + a.antiG()

        if self.mode == FlightMode.PRECISION then
            -- Apply acceleration independently
            ctrl.setEngineCommand(t.engines:Intersection(), { thrustAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 0.001)
            ctrl.setEngineCommand(a.engines:Union(), { adjustAcc:unpack() }, { 0, 0, 0 }, 1, 1, a.prio1Tag, a.prio2Tag, a.prio3Tag, 0.001)
        else
            -- Apply acceleration as a single vector, skipping the adjustment acceleration
            local finalAcc = thrustAcc + adjustAcc
            ctrl.setEngineCommand(t.engines:Union(), { finalAcc:unpack() }, { 0, 0, 0 }, 1, 1, t.prio1Tag, t.prio2Tag, t.prio3Tag, 0.001)
        end
    else
        ctrl.setEngineCommand("all", { 0, 0, 0 }, { 0, 0, 0 }, 1, 1, "", "", "", 0.001)
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
        system.print(state:Name()) -- QQQ
        state:Enter()
    end

    self.current = state
end

function fsm:SetNormalMode()
    self.mode = FlightMode.NORMAL
    log:Info("Normal mode")
end

function fsm:SetPrecisionMode()
    self.mode = FlightMode.PRECISION
    log:Info("Precision mode")
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