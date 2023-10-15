require("abstraction/Vehicle")
require("GlobalTypes")
local s           = require("Singletons")
local log         = s.log
local gateControl = s.gateCtrl
local pub         = s.pub
local universe    = s.universe
local calc        = s.calc
local constants   = s.constants
local brakes      = s.brakes

local AxisManager = require("flight/AxisManager")
local Ternary     = calc.Ternary
local plane       = Plane.NewByVertialReference()
local abs         = math.abs
require("flight/state/Require")

---@module "flight/route/RouteController"

---@class FlightCore
---@field ReceiveEvents fun()
---@field GetRouteController fun():RouteController
---@field NextWP fun()
---@field StartFlight fun()
---@field Turn fun(degrees:number, axis:Vec3):Vec3
---@field AlignTo fun(point:Vec3)
---@field StopEvents fun()
---@field CreateWPFromPoint fun(p:Point, lastInRoute:boolean, pathAlignmentDistanceLimitFromSurface:number):Waypoint
---@field GoIdle fun()
---@field GotoTarget fun(target:Vec3, lockdir:Vec3, margin:number, maxSpeed:number, finalSpeed:number, ignoreLastInRoute:boolean, forceVerticalUp:boolean)
---@field WaitForGate fun():boolean

local FlightCore = {}
FlightCore.__index = FlightCore
local singleton

local defaultFinalSpeed = 0
local defaultMargin = constants.flight.defaultMargin

---Creates a waypoint from a point
---@param point Point
---@param lastInRoute boolean
---@param pathAlignmentDistanceLimitFromSurface number
---@return Waypoint
function FlightCore.CreateWPFromPoint(point, lastInRoute, pathAlignmentDistanceLimitFromSurface)
    local opt = point.Options()
    local lockDir = Vec3.New(opt.Get(PointOptions.LOCK_DIRECTION, Vec3.zero))
    local margin = opt.Get(PointOptions.MARGIN, defaultMargin)
    local finalSpeed
    if opt.Get(PointOptions.FORCE_FINAL_SPEED) then
        finalSpeed = opt.Get(PointOptions.FINAL_SPEED, defaultFinalSpeed)
    else
        finalSpeed = Ternary(lastInRoute, 0, opt.Get(PointOptions.FINAL_SPEED, defaultFinalSpeed))
    end
    local maxSpeed = opt.Get(PointOptions.MAX_SPEED, 0) -- 0 = ignored/max speed.

    local coordinate = universe.ParsePosition(point.Pos()).Coordinates()

    local wp = Waypoint.New(coordinate, finalSpeed, maxSpeed, margin, pathAlignmentDistanceLimitFromSurface)
    wp.SetLastInRoute(lastInRoute)

    if lockDir ~= Vec3.zero then
        wp.LockYawTo(lockDir, true)
    end

    if opt.Get(PointOptions.FORCE_VERT, false) then
        wp.ForceUpAlongVerticalRef()
    end

    return wp
end

---Creates a new FlightCore
---@param routeController RouteController
---@param flightFSM FlightFSM
---@return FlightCore
function FlightCore.New(routeController, flightFSM)
    local s = {}

    local flushHandlerId = 0
    local updateHandlerId = 0
    local axes = AxisManager.Instance()
    local settings = flightFSM.GetSettings()

    local routePublishTimer = Stopwatch.New()

    local function createDefaultWP()
        return Waypoint.New(Current(), 0, 0, defaultMargin, 0)
    end

    -- Setup start waypoints to prevent nil values
    local currentWaypoint = createDefaultWP() -- The positions we want to move to
    local previousWaypoint = currentWaypoint  -- Previous waypoint
    local route = nil ---@type Route|nil

    ---Gets the route controller
    ---@return RouteController
    function s.GetRouteController()
        return routeController
    end

    ---Selects the next waypoint
    function s.NextWP()
        if route == nil then
            return
        end

        local nextPoint = route.Next()
        if nextPoint == nil then
            return
        end

        previousWaypoint = currentWaypoint
        currentWaypoint = FlightCore.CreateWPFromPoint(nextPoint, route.LastPointReached(),
            settings.Number("pathAlignmentDistanceLimitFromSurface"))

        -- When the next waypoint is nearly above or below us, lock yaw
        local dir = (currentWaypoint.Destination() - previousWaypoint.Destination()):NormalizeInPlace()
        if abs(dir:Dot(plane.Up())) > 0.9 then
            currentWaypoint.LockYawTo(plane.Forward(), false)
        end
    end

    function s.WaitForGate()
        return route and gateControl.Enabled() and route.WaitForGate(Current(), settings.Number("openGateMaxDistance"))
    end

    ---Starts the flight
    function s.StartFlight()
        route = routeController.CurrentRoute()
        if not route then
            log.Error("Can't start a flight without a route")
            return
        end

        routePublishTimer.Start()

        -- Setup waypoint that will be the previous waypoint
        currentWaypoint = createDefaultWP()
        s.NextWP()

        if s.WaitForGate() then
            flightFSM.SetState(OpenGates.New(flightFSM, Current(), plane.Forward()))
        else
            flightFSM.SetState(Travel.New(flightFSM))
        end
    end

    function s.GoIdle()
        flightFSM.SetState(Idle.New(flightFSM))
    end

    ---Rotates current waypoint with the given angle
    ---@param degrees number The angle to turn
    ---@param axis Vec3
    ---@return Vec3 # The alignment direction
    function s.Turn(degrees, axis)
        local current = Current()
        local forwardPointOnPlane = calc.ProjectPointOnPlane(axis, current,
            current + Forward() * Waypoint.DirectionMargin)
        forwardPointOnPlane = calc.RotateAroundAxis(forwardPointOnPlane, current, degrees, axis)
        local dir = (forwardPointOnPlane - Current()):NormalizeInPlace()
        currentWaypoint.LockYawTo(dir, true)
        pub.Publish("ForwardDirectionChanged", dir)
        return dir
    end

    ---Aligns to the point
    ---@param point Vec3
    function s.AlignTo(point)
        if currentWaypoint then
            local current = Current()
            local pointOnPlane = calc.ProjectPointOnPlane(-universe.VerticalReferenceVector(), current, point)
            local dir = (pointOnPlane - current):NormalizeInPlace()
            ---QQQ Just (point - curr):NormalizeInPlace() ???
            currentWaypoint.LockYawTo(dir, true)
            pub.Publish("ForwardDirectionChanged", dir)
        end
    end

    ---Hooks up the events needed for flight
    function s.ReceiveEvents()
        ---@diagnostic disable-next-line: undefined-field
        flushHandlerId = system:onEvent("onFlush", s.fcFlush)
        ---@diagnostic disable-next-line: undefined-field
        updateHandlerId = system:onEvent("onUpdate", s.fcUpdate)
        axes.ReceiveEvents()
    end

    ---Disconnects events
    function s.StopEvents()
        ---@diagnostic disable-next-line: undefined-field
        system:clearEvent("flush", flushHandlerId)
        ---@diagnostic disable-next-line: undefined-field
        system:clearEvent("update", updateHandlerId)
        axes.StopEvents()
    end

    ---Starts a movement towards the given coordinate.
    ---@param target Vec3
    ---@param lockDir Vec3 If not zero, direction is locked to this direction
    ---@param margin number meter
    ---@param maxSpeed number m/s
    ---@param finalSpeed number m/s
    ---@param forceFinalSpeed boolean If true, the construct will not slow down to come to a stop if the point is last in the route (used for manual control)
    ---@param forceVerticalUp boolean If true, forces up to align to vertical up
    function s.GotoTarget(target, lockDir, margin, maxSpeed, finalSpeed, forceFinalSpeed, forceVerticalUp)
        local temp = routeController.ActivateTempRoute()
        local targetPoint = temp.AddCoordinate(target)
        local opt = targetPoint.Options()
        opt.Set(PointOptions.MAX_SPEED, maxSpeed)
        opt.Set(PointOptions.MARGIN, margin)
        opt.Set(PointOptions.FINAL_SPEED, finalSpeed)
        opt.Set(PointOptions.FORCE_FINAL_SPEED, forceFinalSpeed)
        opt.Set(PointOptions.FORCE_VERT, forceVerticalUp)

        if not lockDir:IsZero() then
            opt.Set(PointOptions.LOCK_DIRECTION, { lockDir:Unpack() })
        end

        s.StartFlight()
    end

    function s.fcUpdate()
        local status, err, _ = xpcall(
            function()
                flightFSM.Update()
                brakes.BrakeUpdate()

                if route and routePublishTimer.Elapsed() > 0.5 then
                    routePublishTimer.Restart()
                    pub.Publish("RouteData", {
                        remaining = route.GetRemaining(Current()),
                        activeRouteName = routeController.ActiveRouteName()
                    })
                end

                if currentWaypoint ~= nil then
                    pub.Publish("WaypointData", currentWaypoint)

                    if settings.Boolean("setWaypointAlongRoute", false) then
                        system.setWaypoint(universe.CreatePos(currentWaypoint.Destination()).AsPosString(), false)
                    end
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
                if currentWaypoint and route then
                    flightFSM.FsmFlush(currentWaypoint, previousWaypoint)

                    -- The FSM can set a temporary waypoint so we must honor that
                    local selectedWp = flightFSM.SelectWP()

                    axes.SetYawTarget(selectedWp.Yaw(previousWaypoint))
                    axes.SetPitchTarget(selectedWp.Pitch(previousWaypoint))
                    axes.SetRollTarget(selectedWp.Roll(previousWaypoint))

                    if selectedWp.WithinMargin(WPReachMode.ENTRY) then
                        flightFSM.AtWaypoint(route.LastPointReached(), selectedWp, previousWaypoint)

                        -- Lock direction when WP is reached, but don't override existing locks, such as is in place when strafing.
                        local lockDir = (selectedWp.Destination() - previousWaypoint.Destination())
                            :NormalizeInPlace()
                        selectedWp.LockYawTo(lockDir, false)

                        if not flightFSM.PreventNextWp() then
                            -- Switch to next waypoint
                            s.NextWP()
                        end
                    end
                else
                    --- This is a workaround for engines remembering their states from a previous session; shut down all engines.
                    unit.setEngineCommand("all", { 0, 0, 0 }, { 0, 0, 0 }, true, true, "", "", "", 1)
                end

                if not flightFSM.DisablesAllThrust() then
                    axes.Flush()
                end

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
