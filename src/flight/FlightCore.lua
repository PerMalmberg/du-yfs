local AxisControl = require("flight/AxisControl")
local Brakes = require("flight/Brakes")
local FlightFSM = require("flight/FlightFSM")
local EngineGroup = require("du-libs:abstraction/EngineGroup")
local Waypoint = require("flight/Waypoint")
local construct = require("du-libs:abstraction/Construct")()
local visual = require("du-libs:debug/Visual")()
local library = require("du-libs:abstraction/Library")()
local sharedPanel = require("du-libs:panel/SharedPanel")()
local universe = require("du-libs:universe/Universe")()
local checks = require("du-libs:debug/Checks")
local alignment = require("flight/AlignmentFunctions")
local calc = require("du-libs:util/Calc")
local Vec3 = require("cpml/vec3")
require("flight/state/Require")

local nullVec = Vec3()

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
        wWaypointMargin = sharedPanel:Get("Waypoint"):CreateValue("WP margin", "m"),
        wWaypointMaxSpeed = sharedPanel:Get("Waypoint"):CreateValue("WP max. s.", "m/s")
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

    if switched then
        self.waypointReachedSignaled = false
    end

    local current = self:CurrentWP()
    return current, switched
end

function flightCore:StartFlight()
    local fsm = self.flightFSM

    -- Don't start unless we have a destination.
    if #self.waypoints > 0 then
        fsm:SetState(Travel(fsm))
        system.setWaypoint(tostring(universe:CreatePos(self:CurrentWP().destination)))
    else
        self:AddWaypoint(Waypoint(construct.position.Current(), 0.05, 0, noAdjust, noAdjust))
        fsm:SetState(Hold(fsm))
    end
end

-- Rotates all waypoints around the axis with the given angle
function flightCore:Turn(degrees, axis, rotationPoint)
    checks.IsNumber(degrees, "degrees", "flightCore:RotateWaypoints")
    checks.IsVec3(axis, "axis", "flightCore:RotateWaypoints")

    -- Take the next waypoint and rotate it then set a new path from the current location.
    local current = self:CurrentWP()
    -- Can't turn without a waypoint.
    if current ~= nil then
        rotationPoint = (rotationPoint or construct.position.Current())
        current:RotateAroundAxis(degrees, axis, rotationPoint)
        self:ClearWP()
        self:AddWaypoint(current)
        -- Don't restart flight, just let the current flight continue. This avoids engine interruptions.
    end
end

function flightCore:SetFreeMode()
    self.flightFSM:SetFreeMode()
end

function flightCore:SetAxisMode()
    self.flightFSM:SetAxisMode()
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
                    self.wWaypointDistance:Set(calc.Round(wp:DistanceTo(), 3))
                    self.wWaypointMargin:Set(calc.Round(wp.margin, 3))
                    self.wWaypointMaxSpeed:Set(wp.maxSpeed)

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
                    else
                        -- When we go out of range, reset signal so that we get it again when we're back on the waypoint.
                        self.waypointReachedSignaled = false
                    end

                    self:Align(wp)
                    self.flightFSM:FsmFlush(wp, self.previousWaypoint)
                end

                self.pitch:AxisFlush(false)
                self.roll:AxisFlush(false)
                self.yaw:AxisFlush(true)
                self.brakes:BrakeFlush()
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