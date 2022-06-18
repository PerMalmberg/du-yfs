local AxisControl = require("flight/AxisControl")
local Brakes = require("flight/Brakes")
local FlightFSM = require("flight/FlightFSM")
local EngineGroup = require("flight/EngineGroup")
local Waypoint = require("flight/Waypoint")
local construct = require("du-libs:abstraction/Construct")()
local visual = require("du-libs:debug/Visual")()
local library = require("du-libs:abstraction/Library")()
local sharedPanel = require("du-libs:panel/SharedPanel")()
local checks = require("du-libs:debug/Checks")
local alignment = require("flight/AlignmentFunctions")
require("flight/state/Require")

local flightCore = {}
flightCore.__index = flightCore
local singleton

local function new()
    local instance = {
        ctrl = library:GetController(),
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
        waypointReachedSignaled = false,
        wWaypointCount = sharedPanel:Get("Waypoint"):CreateValue("Count", ""),
        wWaypointDistance = sharedPanel:Get("Waypoint"):CreateValue("WP dist.", "m"),
        wWaypointMaxSpeed = sharedPanel:Get("Waypoint"):CreateValue("WP max. s.", "m/s"),
        wWaypointAcc = sharedPanel:Get("Waypoint"):CreateValue("WP acc", "m/s2"),
    }

    setmetatable(instance, flightCore)

    return instance
end

local noAdjust = function()
    return nil
end

function flightCore:AddWaypoint(wp)
    if #self.waypoints == 0 then
        self.previousWaypoint = Waypoint(construct.position.Current(), 0, 0, noAdjust, noAdjust)
    end

    table.insert(self.waypoints, #self.waypoints + 1, wp)
end

function flightCore:ClearWP()
    self.waypoints = {}
    self.previousWaypoint = nil
    self.waypointReachedSignaled = false
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

    -- Don't start unless we have a destination.
    if #self.waypoints > 0 then
        fsm:SetState(Travel(fsm))
    else
        self:AddWaypoint(Waypoint(construct.position.Current(), 0.05, 0, noAdjust, noAdjust))
        fsm:SetState(Hold(fsm))
    end
end

-- Rotates all waypoints around the axis with the given angle
function flightCore:RotateWaypoints(degrees, axis)
    checks.IsNumber(degrees, "degrees", "flightCore:RotateWaypoints")
    checks.IsVec3(axis, "axis", "flightCore:RotateWaypoints")

    for _, w in ipairs(self.waypoints) do
        w:RotateAroundAxis(degrees, axis)
    end
end

function flightCore:ReceiveEvents()
    self.flushHandlerId = system:onEvent("flush", self.FCFlush, self)
    self.updateHandlerId = system:onEvent("update", self.FCUpdate, self)
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
        local target = waypoint:YawAndPitch(self.previousWaypoint)

        if target ~= nil then
            self.yaw:SetTarget(target)
            self.pitch:SetTarget(target)
        else
            self.yaw:Disable()
            self.pitch:Disable()
        end

        local topSideAlignment = waypoint:Roll(self.previousWaypoint)
        if topSideAlignment ~= nil then
            self.roll:SetTarget(topSideAlignment)
        else
            self.roll:Disable()
        end
    end
end

function flightCore:FCUpdate()
    local status, err, _ = xpcall(
            function()
                self.flightFSM:Update()
                self.brakes:Update()

                local wp = self:CurrentWP()
                if wp ~= nil then
                    self.wWaypointCount:Set(#self.waypoints)
                    self.wWaypointDistance:Set(wp:DistanceTo())
                    self.wWaypointMaxSpeed:Set(wp.maxSpeed)
                    self.wWaypointAcc:Set(wp.acceleration)

                    local diff = wp.destination - self.previousWaypoint.destination
                    local len = diff:len()
                    local dir = diff:normalize()
                    visual:DrawNumber(1, self.previousWaypoint.destination)
                    visual:DrawNumber(2, self.previousWaypoint.destination + dir * len / 4)
                    visual:DrawNumber(3, self.previousWaypoint.destination + dir * len / 2)
                    visual:DrawNumber(4, self.previousWaypoint.destination + dir * 3 * len / 4)
                    visual:DrawNumber(5, wp.destination)
                end
            end,
            traceback
    )

    if not status then
        system.print(err)
        unit.exit()
    end
end

function flightCore:FCFlush()
    local status, err, _ = xpcall(
            function()
                local wp = self:CurrentWP()

                if wp ~= nil then
                    if wp:Reached() then
                        if not self.waypointReachedSignaled then
                            self.waypointReachedSignaled = true
                            self.flightFSM:WaypointReached(#self.waypoints == 1, wp, self.previousWaypoint)

                            wp:OneTimeSetYawPitchDirection(construct.orientation.Forward(), alignment.YawPitchKeepWaypointDirectionOrthogonalToGravity)
                        end

                        local switched
                        wp, switched = self:NextWP()
                        if switched then
                            self.waypointReachedSignaled = false
                        end
                    elseif self.waypointReachedSignaled then
                        -- When we go out of range, reset signal so that we get it again when we're back on the waypoint.
                        self.waypointReachedSignaled = false
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