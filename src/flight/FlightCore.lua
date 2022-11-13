local r = require("CommonRequire")
local universe = r.universe
local vehicle = r.vehicle
local checks = r.checks
local calc = r.calc
local Ternary = r.calc.Ternary
local Vec3 = r.Vec3
local nullVec = Vec3.New()
local topics = require("Topics")
local topicNum = topics.numbers
local pub = require("util/PubSub").Instance()

local AxisControl = require("flight/AxisControl")
local Waypoint = require("flight/Waypoint")
local alignment = require("flight/AlignmentFunctions")
local PointOptions = require("flight/route/PointOptions")
require("flight/state/Require")

---@module "flight/route/RouteController"

---@class FlightCore
---@field ReceiveEvents fun()
---@field GetRouteController fun():RouteController
---@field NextWP fun()
---@field StartFlight fun()
---@field Turn fun(degrees:number, axis:Vec3):Vec3
---@field StopEvents fun()
---@field CreateWPFromPoint fun(p:Point):Waypoint


local FlightCore = {}
FlightCore.__index = FlightCore
local singleton

local defaultSpeed = calc.Kph2Mps(50)
local defaultMargin = 0.1 -- m


---Creates a waypoint from a point
---@param point Point
---@param lastInRoute boolean
---@return Waypoint
function FlightCore.CreateWPFromPoint(point, lastInRoute)
    local opt = point.Options()
    local dir = Vec3.New(opt.Get(PointOptions.LOCK_DIRECTION, nullVec))
    local margin = opt.Get(PointOptions.MARGIN, defaultMargin)
    local finalSpeed = Ternary(lastInRoute, 0, opt.Get(PointOptions.FINAL_SPEED, defaultSpeed))
    local maxSpeed = opt.Get(PointOptions.MAX_SPEED, 0) -- 0 = ignored).

    local coordinate = universe.ParsePosition(point.Pos()).Coordinates()
    local wp = Waypoint.New(coordinate, finalSpeed, maxSpeed, margin,
        alignment.RollTopsideAwayFromVerticalReference,
        alignment.YawPitchKeepOrthogonalToVerticalReference)

    wp.SetPrecisionMode(opt.Get(PointOptions.PRECISION, false))

    if dir ~= nullVec then
        wp.LockDirection(dir, true)
    end

    return wp
end

---Creates a new FlightCore
---@param routeController RouteController
---@param flightFSM FlightFSM
---@return FlightCore
function FlightCore.New(routeController, flightFSM)
    local brakes = require("flight/Brakes").Instance()
    local sharedPanel = require("panel/SharedPanel")()
    local p = sharedPanel:Get("Waypoint")
    local s = {}

    local flushHandlerId = 0
    local updateHandlerId = 0
    local pitch = AxisControl(AxisControlPitch)
    local roll = AxisControl(AxisControlRoll)
    local yaw = AxisControl(AxisControlYaw)
    local waypointReachedSignaled = false
    local wWaypointDistance = p:CreateValue("Distance", "m")
    local wWaypointMargin = p:CreateValue("Margin", "m")
    local wWaypointFinalSpeed = p:CreateValue("Final speed", "km/h")
    local wWaypointMaxSpeed = p:CreateValue("Max speed", "km/h")
    local wWaypointPrecision = p:CreateValue("Precision")
    local wWaypointDirLock = p:CreateValue("Dir lock")

    local function createDefaultWP()
        return Waypoint.New(vehicle.position.Current(), 0, 0, 10, alignment.NoAdjust, alignment.NoAdjust)
    end

    -- Setup start waypoints to prevent nil values
    local currentWaypoint = createDefaultWP() -- The positions we want to move to
    local previousWaypoint = currentWaypoint -- Previous waypoint

    ---Gets the route controller
    ---@return RouteController
    function s.GetRouteController()
        return routeController
    end

    ---Selects the next waypoint
    function s.NextWP()
        local route = routeController.CurrentRoute()

        if route == nil then
            return
        end

        local nextPoint = route.Next()
        if nextPoint == nil then
            return
        end

        previousWaypoint = currentWaypoint
        waypointReachedSignaled = false
        currentWaypoint = s.CreateWPFromPoint(nextPoint, route.LastPointReached())
    end

    ---Starts the flight
    function s.StartFlight()
        local fsm = flightFSM

        waypointReachedSignaled = false

        -- Setup waypoint that will be the previous waypoint
        currentWaypoint = createDefaultWP()
        s.NextWP()

        -- Don't start unless we have a destination.
        if currentWaypoint then
            fsm.SetState(Travel.New(fsm))
        else
            fsm.SetState(Hold.New(fsm))
        end
    end

    ---Rotates all waypoints around the axis with the given angle
    ---@param degrees number The angle to turn
    ---@param axis Vec3
    function s.Turn(degrees, axis)
        checks.IsNumber(degrees, "degrees", "s.RotateWaypoints")
        checks.IsVec3(axis, "axis", "s.RotateWaypoints")

        local currentWp = currentWaypoint
        if currentWp then
            local direction = calc.RotateAroundAxis(vehicle.orientation.Forward(), nullVec, degrees, axis)
            currentWp.LockDirection(direction, true)
        end
    end

    ---Hooks up the events needed for flight
    function s.ReceiveEvents()
        ---@diagnostic disable-next-line: undefined-field
        flushHandlerId = system:onEvent("onFlush", s.fcFlush)
        ---@diagnostic disable-next-line: undefined-field
        updateHandlerId = system:onEvent("onUpdate", s.fcUpdate)
        pitch:ReceiveEvents()
        roll:ReceiveEvents()
        yaw:ReceiveEvents()
    end

    ---Disconnects events
    function s.StopEvents()
        ---@diagnostic disable-next-line: undefined-field
        system:clearEvent("flush", flushHandlerId)
        ---@diagnostic disable-next-line: undefined-field
        system:clearEvent("update", updateHandlerId)
        pitch:StopEvents()
        roll:StopEvents()
        yaw:StopEvents()
    end

    local function align()
        local waypoint = currentWaypoint
        local prev = previousWaypoint

        local target = waypoint.YawAndPitch(prev)

        if target ~= nil then
            yaw:SetTarget(target)
            pitch:SetTarget(target)
        else
            yaw:Disable()
            pitch:Disable()
        end

        local topSideAlignment = waypoint.Roll(prev)
        if topSideAlignment ~= nil then
            roll:SetTarget(topSideAlignment)
        else
            roll:Disable()
        end
    end

    function s.fcUpdate()
        local status, err, _ = xpcall(
            function()
                flightFSM.Update()
                brakes:BrakeUpdate()

                local wp = currentWaypoint
                if wp ~= nil then
                    wWaypointDistance:Set(calc.Round(wp.DistanceTo(), 3))
                    pub.Publish(topicNum.wpDist, wp.DistanceTo())
                    wWaypointMargin:Set(calc.Round(wp.Margin(), 3))
                    pub.Publish(topicNum.wpFinalSpeed, calc.Round(calc.Kph2Mps(wp.FinalSpeed()), 1))
                    wWaypointFinalSpeed:Set(calc.Round(calc.Kph2Mps(wp.FinalSpeed()), 1))
                    pub.Publish(topicNum.wpMaxSpeed, calc.Round(calc.Kph2Mps(wp.MaxSpeed()), 1))
                    wWaypointMaxSpeed:Set(calc.Round(calc.Kph2Mps(wp.MaxSpeed()), 1))
                    pub.Publish(topicNum.wpPrecision, wp.GetPrecisionMode())
                    wWaypointPrecision:Set(wp.GetPrecisionMode())
                    pub.Publish(topicNum.wpDirLock, wp.DirectionLocked())
                    wWaypointDirLock:Set(wp.DirectionLocked())
                end
            end,
            traceback
        )

        if not status then
            system.print(err)
            unit.exit()
        end
    end

    function s.fcFlush()
        local status, err, _ = xpcall(
            function()
                local route = routeController.CurrentRoute()
                local wp = currentWaypoint

                if wp and route then
                    if wp.Reached() then
                        if not waypointReachedSignaled then
                            waypointReachedSignaled = true
                            flightFSM.WaypointReached(route.LastPointReached(), wp, previousWaypoint)

                            wp.LockDirection(vehicle.orientation.Forward(), false)
                        end

                        -- Switch to next waypoint
                        s.NextWP()
                    else
                        -- When we go out of range, reset signal so that we get it again when we're back on the waypoint.
                        waypointReachedSignaled = false
                    end

                    align()
                    flightFSM.FsmFlush(currentWaypoint, previousWaypoint)
                else
                    --- This is a workaround for engines remembering their states from a previous session; shut down all engines.
                    unit.setEngineCommand("all", { 0, 0, 0 }, { 0, 0, 0 }, true, true, "", "", "", 1)
                end

                pitch:AxisFlush(false)
                roll:AxisFlush(false)
                yaw:AxisFlush(true)
                brakes:BrakeFlush()
            end,
            traceback
        )

        if not status then
            system.print(err)
            unit.exit()
        end
    end

    singleton = setmetatable(s, FlightCore)
    return singleton
end

-- The module
return FlightCore
