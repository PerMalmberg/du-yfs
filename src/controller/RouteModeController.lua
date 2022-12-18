---@module "commandline/CommandLine"
---@module "input/Input"

local PointOptions = require("flight/route/PointOptions")
local log          = require("debug/Log")()
local vehicle      = require("abstraction/Vehicle").New()
local calc         = require("util/Calc")
local universe     = require("universe/Universe").Instance()

---@class RouteModeController

local RouteModeController = {}
RouteModeController.__index = RouteModeController

---Creates a new RouteModeController
---@param input Input
---@param cmd CommandLine
---@param flightCore FlightCore
---@return ControlInterface
function RouteModeController.New(input, cmd, flightCore)
    local s = {}

    ---@param c Command
    local function addPointOptions(c)
        c.Option("-precision").AsBoolean().Default(false)
        c.Option("-lockdir").AsBoolean().Default(false)
        c.Option("-maxspeed").AsNumber().Default(0)
        c.Option("-margin").AsNumber().Default(0.1)
    end

    ---@param data table
    ---@return PointOptions
    local function createOptions(data)
        local opt = PointOptions.New()
        opt.Set(PointOptions.PRECISION, data.precision)
        opt.Set(PointOptions.MAX_SPEED, calc.Kph2Mps(data.maxspeed))
        opt.Set(PointOptions.MARGIN, data.margin)

        if data.lockdir then
            opt.Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():Unpack() })
        end
        return opt
    end

    function s.Setup()
        local rc = flightCore.GetRouteController()
        cmd.Accept("route-list", function(data)
            local routes = rc.GetRouteNames()
            log:Info(#routes, " available routes")
            for _, r in ipairs(routes) do
                log:Info(r)
            end
        end)

        cmd.Accept("route-edit",
            ---@param data {commandValue:string}
            function(data)
                if rc.EditRoute(data.commandValue) then
                    log:Info("Route open for edit")
                end
            end).AsString()

        cmd.Accept("route-create",
            ---@param data {commandValue:string}
            function(data)
                rc.CreateRoute(data.commandValue)
            end).AsString().Mandatory()

        cmd.Accept("route-save", function(data)
            rc.SaveRoute()
        end).AsEmpty()

        cmd.Accept("route-delete",
            ---@param data {commandValue:string}
            function(data)
                rc.DeleteRoute(data.commandValue)
            end).AsString().Mandatory()

        cmd.Accept("route-print", function(data)
            local route = rc.CurrentEdit()
            if route == nil then
                log:Error("No route being edited")
                return
            end

            for i, p in ipairs(route.Points()) do
                log:Info(i, ":", calc.Ternary(p.HasWaypointRef(), p.WaypointRef(), p.Pos()))

                local opts = p.Options()
                for k, v in pairs(opts.Data()) do
                    log:Info("- ", k, ": ", v)
                end
            end
        end)

        cmd.Accept("route-activate",
            ---@param data {commandValue:string, reverse:boolean}
            function(data)
                local reverse = calc.Ternary(data.reverse or false, RouteOrder.REVERSED, RouteOrder.FORWARD) ---@type RouteOrder

                if rc.ActivateRoute(data.commandValue, reverse) then
                    flightCore.StartFlight()
                    log:Info("Flight started")
                end
            end).AsString().Mandatory()
            .Option("reverse").AsEmptyBoolean()

        cmd.Accept("route-reverse", function(data)
            if rc.ReverseRoute() then
                log:Info("Route reveresed")
            end
        end)

        local addCurrentToRoute = cmd.Accept("route-add-current-pos", function(data)
            local route = rc.CurrentEdit()

            if not route then
                log:Error("No route open for edit")
                return
            end

            local point = route.AddCurrentPos()
            point.SetOptions(createOptions(data))
            log:Info("Added current position to route")
        end).AsEmpty()

        addPointOptions(addCurrentToRoute)

        local addNamed = cmd.Accept("route-add-named-pos",
            ---@param data {commandValue:string}
            function(data)
                local ref = rc.LoadWaypoint(data.commandValue)

                if ref then
                    local route = rc.CurrentEdit()
                    if route == nil then
                        log:Error("No route open for edit")
                    else
                        local p = route.AddWaypointRef(data.commandValue)
                        p.SetOptions(createOptions(data))
                        log:Info("Added position to route")
                    end
                end
            end).AsString()
        addPointOptions(addNamed)

        cmd.Accept("pos-save-as",
            ---@param data {commandValue:string}
            function(data)
                local pos = universe.CreatePos(vehicle.position.Current()).AsPosString()
                if rc.StoreWaypoint(data.commandValue, pos) then
                    log:Info("Position saved as ", data.commandValue)
                end
            end).AsString().Mandatory()

        cmd.Accept("pos-list", function(_)
            for _, data in ipairs(rc.GetWaypoints()) do
                log:Info(data.name, ": ", data.point:Pos())
            end
        end)

        cmd.Accept("pos-delete",
            ---@param data {commandValue:string}
            function(data)
                if rc.DeleteWaypoint(data.commandValue) then
                    log:Info("Waypoint deleted")
                end
            end).AsString().Mandatory()

        local rel = cmd.Accept("pos-create-along-gravity",
            ---@param data {commandValue:string, u:number}
            function(data)
                local pos = vehicle.position.Current() - universe.VerticalReferenceVector() * data.u
                local posStr = universe.CreatePos(pos).AsPosString()
                if rc.StoreWaypoint(data.commandValue, posStr) then
                    log:Info("Stored postion ", posStr, " as ", data.commandValue)
                end
            end).AsString().Mandatory()
        rel.Option("-u").AsNumber().Mandatory()
    end

    function s.TearDown()
        input.Clear()
        cmd.Clear()
    end

    return setmetatable(s, RouteModeController)
end

return RouteModeController
