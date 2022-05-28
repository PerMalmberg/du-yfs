local diag = require("Diagnostics")()
local library = require("abstraction/Library")()
local vec3 = require("cpml/vec3")
local brakes = require("Brakes")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")
local ctrl = library.GetController()
local sharedPanel = require("panel/SharedPanel")()
local utils = require("cpml/utils")
local PID = require("cpml/PID")
local Waypoint = require("movement/WayPoint")
local abs = math.abs
local min = math.min
local max = math.max

local nullVec = vec3()
local nullTri = {0, 0, 0}
local BRAKE_MARK = "MoveControl"

local moveControl = {}
moveControl.__index = moveControl
local singelton = nil

local function new()
    local instance = {
        waypoints = {}, -- The positions we want to move to
        previousWaypoint = nil,
        wWaypoints = sharedPanel:Get("Move Control"):CreateValue("Waypoints", ""),
        forcedBrake = false,
        wMode = sharedPanel:Get("Move Control"):CreateValue("Mode", "m"),
        wDeviation = sharedPanel:Get("Move Control"):CreateValue("Deviation", "m"),
        wAlignment = sharedPanel:Get("Move Control"):CreateValue("Alignment", ""),
        wMargin = sharedPanel:Get("Move Control"):CreateValue("Margin", "m"),
        wVel = sharedPanel:Get("Move Control"):CreateValue("Vel.", "m/s"),
        wToDest = sharedPanel:Get("Move Control"):CreateValue("To dest", "m"),
        deviationPID = PID(0, 0.8, 0.2, 0.5),
        approachSpeed = nil
    }

    setmetatable(instance, moveControl)

    ctrl.setEngineCommand("ALL", nullTri, nullTri)

    return instance
end

local function Direction(from, to)
    return (to - from):normalize_inplace()
end

function moveControl:AddWaypoint(wp)
    table.insert(self.waypoints, #self.waypoints + 1, wp)
    if #self.waypoints == 1 then
        local noAdjust = function()
            return nil
        end
        self.previousWaypoint = Waypoint(construct.position.Current(), 0, 0, noAdjust, noAdjust)
        self.approachSpeed = wp.maxSpeed
    end
end

function moveControl:Clear()
    self.waypoints = {}
end

function moveControl:Current()
    return self.waypoints[1]
end

function moveControl:Next()
    local switched = false

    if #self.waypoints > 1 then
        self.previousWaypoint = table.remove(self.waypoints, 1)
        switched = true
    end

    local current = self:Current()

    return current, switched
end

function moveControl:SetBrake(enabled)
    self.forcedBrake = enabled
end

function moveControl:Move()
    local currentPos = construct.position.Current()
    local wp = self:Current()
    local toWaypoint = wp.destination - currentPos
    local distanceToWaypoint = toWaypoint:len()
    local directionToWaypoint = toWaypoint:normalize()
    local velocity = construct.velocity.Movement()
    local speed = velocity:len()

    local desiredAcceleration = 5

    local mode

    -- Always counter gravity so we don't have to think about it in
    -- other calculations, i.e. pretend we're in space.
    local deviationAcceleration, deviationLength = self:AdjustForDeviation(wp, currentPos)
    local acceleration = -construct.world.GAlongGravity() + deviationAcceleration

    local alignment = directionToWaypoint:dot(velocity:normalize())
    self.wAlignment:Set(calc.Round(alignment, 4))

    if wp:Reached(currentPos) then
        brakes:SetPart(BRAKE_MARK, true) -- This is for the last waypoint
        mode = "Hold"
    elseif alignment < 0.9 and speed > calc.Kph2Mps(1) then -- Moving in the right direction? Speed check to prevent self-lock.
        mode = "Not aligned"
        brakes:SetPart(BRAKE_MARK, true)
    else
        local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance()
        if brakeDistance >= distanceToWaypoint then
            acceleration = acceleration - velocity:normalize() * brakeAccelerationNeeded
            brakes:SetPart(BRAKE_MARK, true)
            mode = "Approaching"
            self.approachSpeed = utils.clamp(self.approachSpeed, calc.Kph2Mps(2), wp.maxSpeed)
        elseif speed <= self.approachSpeed then
            acceleration = acceleration + directionToWaypoint * desiredAcceleration
            mode = "Accelerating"
        elseif speed > self.approachSpeed then
            brakes:SetPart(BRAKE_MARK, true)
            mode = "Slowing down"
        end
    end

    self.wMode:Set(mode)

    return acceleration
end

function moveControl:AdjustForDeviation(waypoint, currentPos)
    local nearestPoint = self:NearestPointBetweenWaypoints(self.previousWaypoint, waypoint, currentPos)
    local deviation = nearestPoint - currentPos
    local len = deviation:len()

    self.deviationPID:inject(len)
    self.wDeviation:Set(calc.Round(len, 4))

    return deviation:normalize() * utils.clamp(self.deviationPID:get(), 0, 2), len
end

function moveControl:Flush()
    brakes:SetPart(BRAKE_MARK, self.forcedBrake)

    local acceleration = nullVec
    local wp = self:Current()
    local currentPos = construct.position.Current()

    if wp == nil then
        self.wVel:Set("-")
        self.wToDest:Set("-")
        self.wMargin:Set("-")
        self.wDeviation:Set("-")
        self.wAlignment:Set("-")

        -- Enable brakes if we don't have a waypoint
        brakes:SetPart(BRAKE_MARK, true)
    else
        if wp:Reached(currentPos) then
            local switched
            wp, switched = self:Next()
            if switched then
                self.approachSpeed = wp.maxSpeed
            end
        end

        self.wVel:Set(calc.Round(construct.velocity.Movement():len(), 2) .. "/" .. calc.Round(self.approachSpeed, 2))
        self.wToDest:Set((wp.destination - currentPos):len())
        self.wMargin:Set(wp.margin)

        acceleration = self:Move()

        diag:DrawNumber(0, construct.position.Current() + acceleration:normalize() * 5)
        diag:DrawNumber(1, wp.destination)
        diag:DrawNumber(9, self.previousWaypoint.destination)
    end

    ctrl.setEngineCommand("thrust", {acceleration:unpack()})
end

function moveControl:NearestPointBetweenWaypoints(wpStart, wpEnd, currentPos)
    local diff = wpEnd.destination - wpStart.destination
    local dirToEnd = diff:normalize()
    local nearestPoint = calc.NearestPointOnLine(wpStart.destination, dirToEnd, currentPos)
    local dirToNearest = nearestPoint - wpEnd.destination
    -- Is the point past the end?
    if dirToNearest:normalize():dot(dirToEnd) > 0 then
        return wpEnd.destination
    else
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
            if singelton == nil then
                singelton = new()
            end
            return singelton
        end
    }
)
