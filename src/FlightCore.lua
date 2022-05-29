---@diagnostic disable: undefined-doc-name


local library = require("abstraction/Library")()
local construct = require("abstraction/Construct")()
local sharedPanel = require("panel/SharedPanel")()
local EngineGroup = require("EngineGroup")
local Brakes = require("Brakes")
local AxisControl = require("AxisControl")
local Waypoint = require("movement/WayPoint")
local FlightFSM = require("movement/FlightFSM")
local MoveTowardsWaypoint = require("movement/state/MoveTowardsWaypoint")
local diag = require("Diagnostics")()

local flightCore = {}
flightCore.__index = flightCore
local singleton

local function new()
    local ctrl = library.GetController()
    local instance = {
        ctrl = ctrl,
        brakes = Brakes(),
        thrustGroup = EngineGroup("thrust"),
        autoStabilization = nil,
        flushHandlerId = 0,
        updateHandlerId = 0,
        pitch = AxisControl(AxisControlPitch),
        roll = AxisControl(AxisControlRoll),
        yaw = AxisControl(AxisControlYaw),
        flightFSM = FlightFSM(),
        waypoints = {}, -- The positions we want to move to
        previousWaypoint = nil, -- Previous waypoint
        wWaypointDistance = sharedPanel:Get("Waypoint"):CreateValue("WP dist.", "m"),
        wWaypointMaxSpeed = sharedPanel:Get("Waypoint"):CreateValue("WP max. s.", "m/s"),
        wWaypointAcc = sharedPanel:Get("Waypoint"):CreateValue("WP acc", "m/s2"),
    }

    setmetatable(instance, flightCore)

    return instance
end

function flightCore:AddWaypoint(wp)
    table.insert(self.waypoints, #self.waypoints + 1, wp)
    if #self.waypoints == 1 then
        local noAdjust = function()
            return nil
        end
        self.previousWaypoint = Waypoint(construct.position.Current(), 0, 0, noAdjust, noAdjust)
        self.approachSpeed = wp.maxSpeed
    end
end

function flightCore:ClearWP()
    self.waypoints = {}
    self.previousWaypoint = nil
end

function flightCore:CurrentWP()
    return self.waypoints[1]
end

function flightCore:NextWP()
    local switched = false

    if #self.waypoints > 1 then
        self.previousWaypoint = table.remove(self.waypoints, 1)
        switched = true
    end

    local current = self:CurrentWP()

    return current, switched
end

function flightCore:StartFlight()
    local fsm = self.flightFSM
    fsm:SetState(MoveTowardsWaypoint(fsm))
end

function flightCore:ReceiveEvents()
    self.flushHandlerId = system:onEvent("flush", self.Flush, self)
    self.updateHandlerId = system:onEvent("update", self.Update, self)
    self.pitch:ReceiveEvents()
    self.roll:ReceiveEvents()
    self.yaw:ReceiveEvents()
end

function flightCore:StopEvents()
    system:clearEvent("flush", self.flushHandlerId)
    system:clearEvent("update", self.updateHandlerId)
    self.pitch:StopEvents()
    self.roll:StopEvents()
    self.yaw:StopEvents()
end

function flightCore:Align(waypoint)
    if waypoint ~= nil then
        local target = waypoint:YawAndPitch()

        if target ~= nil then
            self.yaw:SetTarget(target)
            self.pitch:SetTarget(target)
        else
            self.yaw:Disable()
            self.pitch:Disable()
        end

        local topSideAlignment = waypoint:Roll()
        if topSideAlignment ~= nil then
            self.roll:SetTarget(topSideAlignment)
        else
            self.roll:Disable()
        end
    end
end

function flightCore:Update()
    local status, err, _ =
        xpcall(
        function()
            self.flightFSM:Update()
            self.brakes:Update()

            local wp = self:CurrentWP()
            if wp ~= nil then
                self.wWaypointDistance:Set(wp:DistanceTo())
                self.wWaypointMaxSpeed:Set(wp.maxSpeed)
                self.wWaypointAcc:Set(wp.acceleration)
                diag:DrawNumber(0, construct.position.Current() * wp:DirectionTo() * 5)
                diag:DrawNumber(1, wp.destination)
                diag:DrawNumber(2, self.previousWaypoint.destination)
            end

        end,
        traceback
    )

    if not status then
        system.print(err)
        unit.exit()
    end
end

function flightCore:Flush()
    local status, err, _ =
        xpcall(
        function()
            local wp = self:CurrentWP()

            if wp ~= nil then
                if wp:Reached() then
                    local switched
                    wp, switched = self:NextWP()
                end
                self:Align(wp)
                self.flightFSM:Flush(wp, self.previousWaypoint)
            end

            self.pitch:Flush(false)
            self.roll:Flush(false)
            self.yaw:Flush(true)
            self.brakes:Flush()
        end,
        traceback
    )

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
            if singleton == nil then
                singleton = new()
            end
            return singleton
        end
    }
)