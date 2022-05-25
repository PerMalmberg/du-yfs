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
        pid = PID(0.01, 0.2, 0, 0.5)
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
    local ownPos = construct.position.Current()
    local wp = self:Current()
    local toDest = wp.destination - ownPos
    local distanceToWaypoint = toDest:len()
    local velocity = construct.velocity.Movement()
    local speed = velocity:len()

    local acceleration = nullVec

    local mode

    -- 1 fully aligned, 0 not aligned to destination
    local travelAlignment = utils.clamp(velocity:normalize():dot(toDest:normalize()), 0, 1)

    local desiredAcceleration = 5
    if travelAlignment < 0.99 then
        desiredAcceleration = 1
    end

    if brakes:BrakeDistance() >= distanceToWaypoint * 1.05 then
        brakes:SetPart(BRAKE_MARK, true)
        -- Use engines to brake too if needed
        acceleration = -velocity:normalize() * brakes:AdditionalAccelerationNeededToStop(distanceToWaypoint, speed)
        mode = "Braking - final"
    elseif wp:Reached(ownPos) then
        brakes:SetPart(BRAKE_MARK, true)
        mode = "Hold"
    elseif travelAlignment < 0.75 and speed > 0.5 then -- Speed check needed to prevent getting stuck due to brakes being stronger than acceleration
        -- If we're deviating, make use of brakes to reduce overshoot
        brakes:SetPart(BRAKE_MARK, true)
        mode = "Deviating"
        acceleration = toDest:normalize() * desiredAcceleration
    elseif speed >= wp.maxSpeed * 1.01 then
        acceleration = -velocity:normalize() * desiredAcceleration
        mode = "Braking"
    elseif speed < wp.maxSpeed then
        mode = "Accelerating"
        acceleration = toDest:normalize() * desiredAcceleration
    else
        mode = "Maintain"
    end

    self.wMode:Set(mode .. " " .. calc.Round(travelAlignment, 3))

    -- Always counter gravity if some command has been given,
    -- so we don't have to think about it in other calculations, i.e. pretend we're in space.
    acceleration = acceleration - construct.world.GAlongGravity()

    return acceleration
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
        end

        self.wVel:Set(calc.Round(construct.velocity.Movement():len(), 2) .. "/" .. calc.Round(wp.maxSpeed, 2))
        self.wToDest:Set((wp.destination - currentPos):len())
        self.wMargin:Set(wp.margin)

        acceleration = self:Move()

        local nearestPoint = calc.NearestPointOnLine(wp.destination, Direction(self.previousWaypoint.destination, wp.destination), currentPos)
        local deviation = nearestPoint - currentPos
        self.pid:inject(deviation:len())

        acceleration = acceleration + deviation:normalize() * utils.clamp(self.pid:get(), 0, 1)

        self.wDeviation:Set(calc.Round(deviation:len(), 4))

        diag:DrawNumber(0, construct.position.Current() + acceleration:normalize() * 5)
        diag:DrawNumber(1, wp.destination)
        diag:DrawNumber(9, wp.destination)
    end

    ctrl.setEngineCommand("thrust", {acceleration:unpack()})
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
