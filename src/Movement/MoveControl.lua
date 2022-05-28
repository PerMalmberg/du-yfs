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
local BRAKE_MARK = "MoveControlBrake"

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
        wMargin = sharedPanel:Get("Move Control"):CreateValue("Margin", "m"),
        wVel = sharedPanel:Get("Move Control"):CreateValue("Vel.", "m/s"),
        wToDest = sharedPanel:Get("Move Control"):CreateValue("To dest", "m"),
        pid = PID(1, 0.12, 0, 0.5),
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
    local toDest = wp.destination - currentPos
    local distanceToWaypoint = toDest:len()
    local travelDirection = toDest:normalize()
    local velocity = construct.velocity.Movement()
    local speed = velocity:len()

    local acceleration = nullVec

    -- 1 fully aligned, 0 not aligned to destination
    local travelAlignment = utils.clamp(velocity:normalize():dot(travelDirection), 0, 1)

    local desiredAcceleration = 5

    if travelAlignment < 0.99 then
        desiredAcceleration = 1
    end

    local mode
    local brakeDistance, brakeAccelerationNeeded = brakes:BrakeDistance()

    if brakeDistance >= distanceToWaypoint then
        brakes:SetPart(BRAKE_MARK, true)
        -- Use engines to brake too if needed
        acceleration = -velocity:normalize() * brakeAccelerationNeeded
        mode = "Braking - final"
        local _1kmph = calc.Kph2Mps(1)
        self.approachSpeed = utils.clamp(min(self.approachSpeed, speed), min(_1kmph, wp.maxSpeed), max(_1kmph, wp.maxSpeed))
    elseif wp:Reached(currentPos) then
        brakes:SetPart(BRAKE_MARK, true)
        mode = "Hold"
    elseif travelAlignment < 0.95 and speed > calc.Kph2Mps(5) then -- Speed check needed to prevent getting stuck due to brakes being stronger than acceleration
        -- If we're deviating, make use of brakes to reduce overshoot
        acceleration = travelDirection * desiredAcceleration
        brakes:SetPart(BRAKE_MARK, true)
        mode = "Deviating"
    elseif speed >= self.approachSpeed then
        brakes:SetPart(BRAKE_MARK, true)
        --acceleration = -velocity:normalize() * desiredAcceleration
        mode = "Braking"
    elseif speed < self.approachSpeed then
        mode = "Accelerating"
        acceleration = travelDirection * desiredAcceleration
    else
        mode = "Maintain"
    end

    self.wMode:Set(mode .. " " .. calc.Round(travelAlignment, 3))

    acceleration = acceleration + self:AdjustForDeviation(wp, currentPos)

    -- Always counter gravity so we don't have to think about it in
    -- other calculations, i.e. pretend we're in space.
    acceleration = acceleration - construct.world.GAlongGravity()

    return acceleration
end

function moveControl:AdjustForDeviation(waypoint, currentPos)
    local nearestPoint = self:NearestPointBetweenWaypoints(self.previousWaypoint, waypoint, currentPos)
    local deviation = nearestPoint - currentPos
    self.pid:inject(deviation:len())

    self.wDeviation:Set(calc.Round(deviation:len(), 4))

    return deviation:normalize() * utils.clamp(self.pid:get(), 0, 1)
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
