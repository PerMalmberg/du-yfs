local diag = require("Diagnostics")()
local library = require("abstraction/Library")()
local vec3 = require("cpml/vec3")
local brakes = require("Brakes")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")
local ctrl = library.GetController()
local sharedPanel = require("panel/SharedPanel")()
local Rabbit = require("movement/Rabbit")
local utils = require("cpml/utils")
local PID = require("cpml/PID")
local abs = math.abs

local nullVec = vec3()
local nullTri = {0, 0, 0}
local BRAKE_MARK = "MoveControlBrake"
local DISTANCE_BETWEEN_TRAVEL_POINTS = 1

local moveControl = {}
moveControl.__index = moveControl
local singelton = nil

local function new()
    local instance = {
        waypoints = {}, -- The positions we want to move to
        wWaypoints = sharedPanel:Get("Move Control"):CreateValue("Waypoints", ""),
        rabbit = nil,
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
        self:NewRabbit(construct.position.Current(), self:Current())
    end
end

function moveControl:Clear()
    self.waypoints = {}
    self.rabbit = nil
end

function moveControl:Current()
    return self.waypoints[1]
end

function moveControl:Next()
    local switched = false
    local prev = self:Current()

    if #self.waypoints > 1 then
        table.remove(self.waypoints, 1)
        switched = true
    end

    local current = self:Current()

    if switched then
        if prev == nil then
            self:NewRabbit(construct.position.Current(), current)
        else
            self:NewRabbit(prev.destination, current)
        end
    end

    return current, switched
end

function moveControl:NewRabbit(travelOrigin, waypoint)
    diag:AssertIsVec3(travelOrigin, "travelOrigin", "moveControl:NewRabbit")
    diag:AssertIsTable(waypoint, "waypoint", "moveControl:NewRabbit")

    local direction = Direction(travelOrigin, waypoint.destination)
    self.rabbit = Rabbit(travelOrigin + direction * DISTANCE_BETWEEN_TRAVEL_POINTS, waypoint.destination, waypoint.maxSpeed)
end

function moveControl:SetBrake(enabled)
    self.forcedBrake = enabled
end

function moveControl:Move(rabbitPos)
    local ownPos = construct.position.Current()
    local toDest = rabbitPos - ownPos
    local distance = toDest:len()
    local velocity = construct.velocity.Movement()
    local speed = velocity:len()
    local wp = self:Current()

    local acceleration = nullVec

    local mode

    -- 1 fully aligned, 0 not aligned to destination
    local travelAlignment = utils.clamp(velocity:normalize():dot(toDest:normalize()), 0, 1)

    local desiredAcceleration = 1

    if brakes:BrakeDistance() >= distance then
        brakes:SetPart(BRAKE_MARK, true)
        -- Use engines to brake too if needed
        acceleration = -velocity:normalize() * brakes:AdditionalAccelerationNeededToStop(distance, speed)
        mode = "Braking - final"
    elseif travelAlignment < 0.75 and speed > 0.1 then -- Speed check needed to prevent getting stuck due to brakes being stronger than acceleration
        -- If we're deviating, make use of brakes to reduce overshoot
        brakes:SetPart(BRAKE_MARK, true)
        mode = "Deviating " .. calc.Round(travelAlignment, 3)
        acceleration = toDest:normalize() * desiredAcceleration
    elseif speed >= wp.maxSpeed * 1.01 then
        acceleration = -velocity:normalize() * desiredAcceleration
        mode = "Braking"
    else
        mode = "Accelerating"
        acceleration = toDest:normalize() * desiredAcceleration
    end

    self.wMode:Set(mode)

    -- Always counter gravity if some command has been given,
    -- so we don't have to think about it in other calculations, i.e. pretend we're in space.
    acceleration = acceleration - construct.world.GAlongGravity()

    return acceleration
end

function moveControl:Flush()
    local f = function()
        brakes:SetPart(BRAKE_MARK, self.forcedBrake)

        local acceleration = nullVec
        local wp = self:Current()
        local currentPos = construct.position.Current()

        if wp == nil or self.rabbit == nil then
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

            local rabbitPos = self.rabbit:Current(currentPos, 3)
            acceleration = self:Move(rabbitPos)

            local nearestPoint = calc.NearestPointOnLine(self.rabbit.origin, self.rabbit.destination - self.rabbit.origin, currentPos)
            self.wDeviation:Set(calc.Round((nearestPoint - currentPos):len(), 4))

            diag:DrawNumber(0, construct.position.Current() + acceleration:normalize() * 5)
            diag:DrawNumber(1, wp.destination)
            diag:DrawNumber(2, self.rabbit.destination)
            diag:DrawNumber(9, rabbitPos)
        end

        ctrl.setEngineCommand("thrust", {acceleration:unpack()})
    end

    local status, err, ret = xpcall(f, traceback)
    if not status then
        system.print(err)
        unit.exit()
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
