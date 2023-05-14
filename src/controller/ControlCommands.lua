---@module "commandline/CommandLine"
---@module "input/Input"

local Criteria                = require("input/Criteria")
local PointOptions            = require("flight/route/PointOptions")
local Vec3                    = require("math/Vec3")
local log                     = require("debug/Log")()
local vehicle                 = require("abstraction/Vehicle").New()
local brakes                  = require("flight/Brakes").Instance()
local calc                    = require("util/Calc")
local universe                = require("universe/Universe").Instance()
local keys                    = require("input/Keys")
local alignment               = require("flight/AlignmentFunctions")
local pub                     = require("util/PubSub").Instance()
local VerticalReferenceVector = universe.VerticalReferenceVector
local Current                 = vehicle.position.Current
local Forward                 = vehicle.orientation.Forward
local Right                   = vehicle.orientation.Right
local Up                      = vehicle.orientation.Up

---@alias PointOptionArguments { commandValue:string, maxspeed:number, margin:number, lockdir:boolean}

---@class ControlCommands
---@field New fun(input:Input, cmd:Command, flightCore:FlightCore)
---@field RegisterCommonCommands fun()
---@field RegisterRouteCommands fun()
---@field RegisterMoveCommands fun()

local ControlCommands         = {}
ControlCommands.__index       = ControlCommands

---Creates a new RouteModeController
---@param input Input
---@param cmd CommandLine
---@param flightCore FlightCore
---@param settings Settings
---@param screenCtrl ScreenController
---@return ControlCommands
function ControlCommands.New(input, cmd, flightCore, settings, screenCtrl)
    local s = {}

    local rc = flightCore.GetRouteController()

    local function holdPosition()
        local r = rc.ActivateTempRoute().AddCurrentPos()
        r.Options().Set(PointOptions.LOCK_DIRECTION, { Forward():Unpack() })
        flightCore.StartFlight()
    end

    ---@param c Command
    local function addPointOptions(c)
        c.Option("-lockdir").AsEmptyBoolean().Default(false)
        c.Option("-maxspeed").AsNumber().Default(0)
        c.Option("-margin").AsNumber().Default(0.1)
    end

    ---@param data PointOptionArguments
    ---@return PointOptions
    local function createOptions(data)
        local opt = PointOptions.New()
        opt.Set(PointOptions.MAX_SPEED, calc.Kph2Mps(data.maxspeed))
        opt.Set(PointOptions.MARGIN, data.margin)

        if data.lockdir then
            opt.Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():Unpack() })
        end
        return opt
    end

    function s.RegisterCommonCommands()
        -- Setup brakes
        input.Register(keys.brake, Criteria.New().OnPress(), function() brakes.Forced(true) end)
        input.Register(keys.brake, Criteria.New().OnRelease(), function() brakes.Forced(false) end)

        cmd.Accept("idle", function(data)
            log:Info("Going idle!")
            flightCore.GoIdle()
        end)

        cmd.Accept("hold", function(data)
            holdPosition()
        end)

        cmd.Accept("print-pos", function(_)
            log:Info("Current pos:", universe.CreatePos(Current()):AsPosString())
            log:Info("Alignment pos:",
                universe.CreatePos(Current() + vehicle.orientation.Forward() * alignment.DirectionMargin):AsPosString())
        end)

        cmd.Accept("show-widgets",
            ---@param data {commandValue:boolean}
            function(data)
                pub.Publish("ShowInfoWidgets", data.commandValue)
            end).AsBoolean().Mandatory()
    end

    ---Get the route being edited
    ---@return Route|nil
    local function getEditRoute()
        local route = rc.CurrentEdit()
        if route == nil then
            log:Error("No route being edited")
        end

        return route
    end

    function s.RegisterRouteCommands()
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

        cmd.Accept("route-discard", function(data)
            rc.Discard()
        end)

        cmd.Accept("route-delete",
            ---@param data {commandValue:string}
            function(data)
                rc.DeleteRoute(data.commandValue)
            end).AsString().Mandatory()

        cmd.Accept("route-print", function(data)
            local route = getEditRoute()
            if route == nil then
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
            ---@param data {commandValue:string, index:number}
            function(data)
                local startMargin = settings.Number("routeStartDistanceLimit")

                if rc.ActivateRoute(data.commandValue, data.index, startMargin) then
                    flightCore.StartFlight()
                    pub.Publish("RouteActivated", true)
                    log:Info("Flight started")
                end
            end).AsString().Mandatory()
            .Option("index").AsNumber()

        local addCurrentToRoute = cmd.Accept("route-add-current-pos",
            ---@param data PointOptionArguments
            function(data)
                local route = getEditRoute()
                if route == nil then
                    return
                end

                local point = route.AddCurrentPos()
                point.SetOptions(createOptions(data))
                log:Info("Added current position to route")
            end).AsEmpty()

        addPointOptions(addCurrentToRoute)

        local addNamed = cmd.Accept("route-add-named-pos",
            ---@param data PointOptionArguments
            function(data)
                local ref = rc.LoadWaypoint(data.commandValue)

                if ref then
                    local route = getEditRoute()
                    if route == nil then
                        return
                    end
                    local p = route.AddWaypointRef(data.commandValue, ref.Pos())
                    if p then
                        p.SetOptions(createOptions(data))
                        log:Info("Added position to route")
                    else
                        log:Error("Could not add postion")
                    end
                end
            end).AsString()
        addPointOptions(addNamed)

        cmd.Accept("route-delete-pos",
            ---@param data {commandValue:number}
            function(data)
                local route = getEditRoute()
                if route == nil then
                    return
                end
                if route.RemovePoint(data.commandValue) then
                    log:Info("Point removed")
                else
                    log:Error("Could not remove point")
                end
            end).AsNumber().Mandatory()

        ---@param from integer
        ---@param to integer
        local function movePoint(from, to)
            local route = getEditRoute()
            if route == nil then
                return
            end
            if route.MovePoint(from, to) then
                log:Info("Point moved:", from, " -> ", to)
            else
                log:Error("Could not move point")
            end
        end

        local movePos = cmd.Accept("route-move-pos",
            ---@param data {from:number, to:number}
            function(data)
                movePoint(data.from, data.to)
            end)
        movePos.Option("from").AsNumber().Mandatory()
        movePos.Option("to").AsNumber().Mandatory()

        cmd.Accept("route-move-pos-forward",
            ---@param data {commandValue:number}
            function(data)
                local ix = data.commandValue
                movePoint(ix, ix + 1)
            end).AsNumber().Mandatory()

        cmd.Accept("route-move-pos-back",
            ---@param data {commandValue:number}
            function(data)
                local ix = data.commandValue
                movePoint(ix, ix - 1)
            end).AsNumber().Mandatory()

        cmd.Accept("route-set-all-margins",
            ---@param data {commandValue:number}
            function(data)
                local route = getEditRoute()
                if route == nil then
                    return
                end
                for _, value in ipairs(route.Points()) do
                    value.Options().Set(PointOptions.MARGIN, data.commandValue)
                end
                log:Info("Margins on all points in route set to ", data.commandValue)
            end).AsNumber().Mandatory()

        cmd.Accept("route-set-all-max-speeds",
            ---@param data {commandValue:number}
            function(data)
                local route = getEditRoute()
                if route == nil then
                    return
                end
                local newSpeed = calc.Kph2Mps(data.commandValue)
                for _, value in ipairs(route.Points()) do
                    value.Options().Set(PointOptions.MAX_SPEED, newSpeed)
                end
                log:Info("Max speeds on all points in route set to ", data.commandValue, "km/h")
            end).AsNumber().Mandatory()

        local cmdPosSkippable = cmd.Accept("route-set-pos-option",
            ---@param data {commandValue:number, toggleSkippable:boolean, toggleSelectable:boolean}
            function(data)
                local route = getEditRoute()
                if route == nil then
                    return
                end

                if data.toggleSkippable then
                    local newValue = not route.GetPointOption(data.commandValue, PointOptions.SKIPPABLE, false)
                    route.SetPointOption(data.commandValue, PointOptions.SKIPPABLE, newValue)
                    log:Info("Set skippable option to ", newValue)
                end

                if data.toggleSelectable then
                    local newValue = not route.GetPointOption(data.commandValue, PointOptions.SELECTABLE, true)
                    route.SetPointOption(data.commandValue, PointOptions.SELECTABLE, newValue)
                    log:Info("Set selectable option to", newValue)
                end
            end).AsNumber()
        cmdPosSkippable.Option("toggleSkippable").AsEmptyBoolean()
        cmdPosSkippable.Option("toggleSelectable").AsEmptyBoolean()

        cmd.Accept("pos-save-current-as",
            ---@param data {commandValue:string}
            function(data)
                local pos = universe.CreatePos(Current()).AsPosString()
                if rc.StoreWaypoint(data.commandValue, pos) then
                    log:Info("Current position saved as ", data.commandValue)
                end
            end).AsString().Mandatory()

        cmd.Accept("pos-save-as",
            ---@param data {commandValue:string, pos:string}
            function(data)
                local p = universe.ParsePosition(data.pos)
                if p then
                    if rc.StoreWaypoint(data.commandValue, p.AsPosString()) then
                        log:Info("Current position saved as ", data.commandValue)
                    end
                end
            end).AsString().Mandatory().Option("pos").AsString().Mandatory()

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

        local alongGrav = cmd.Accept("pos-create-along-gravity",
            ---@param data {commandValue:string, u:number}
            function(data)
                local pos = Current() - universe.VerticalReferenceVector() * data.u
                local posStr = universe.CreatePos(pos).AsPosString()
                if rc.StoreWaypoint(data.commandValue, posStr) then
                    log:Info("Stored postion ", posStr, " as ", data.commandValue)
                end
            end).AsString().Mandatory()
        alongGrav.Option("-u").AsNumber().Mandatory()

        local relative = cmd.Accept("pos-create-relative",
            ---@param data {commandValue:string, u:number, f:number, r:number}
            function(data)
                local f = data.f or 0
                local u = data.u or 0
                local r = data.r or 0
                if f == 0 and u == 0 and r == 0 then
                    log:Error("Must provide atleast one direction distance")
                else
                    local pos = Current() + Forward() * f + Right() * r + Up() * u
                    local posStr = universe.CreatePos(pos).AsPosString()
                    if rc.StoreWaypoint(data.commandValue, posStr) then
                        log:Info("Stored postion ", posStr, " as ", data.commandValue)
                    end
                end
            end).AsString().Mandatory()
        relative.Option("u").AsNumber()
        relative.Option("f").AsNumber()
        relative.Option("r").AsNumber()

        local printRelative = cmd.Accept("pos-print-relative",
            ---@param data {u:number, f:number, r:number}
            function(data)
                local f = data.f or 0
                local u = data.u or 0
                local r = data.r or 0
                if f == 0 and u == 0 and r == 0 then
                    log:Error("Must provide atleast one direction distance")
                else
                    local pos = Current() + Forward() * f + Right() * r + Up() * u
                    local posStr = universe.CreatePos(pos).AsPosString()
                    log:Info("Position is at: ", posStr)
                end
            end)
        printRelative.Option("u").AsNumber()
        printRelative.Option("f").AsNumber()
        printRelative.Option("r").AsNumber()


        ---@param data {x:number, y:number, z:number}
        ---@return number
        local function countProvidedVectorParts(data)
            local count = 0

            for _, value in ipairs({ "x", "y", "z" }) do
                if data[value] ~= nil then count = count + 1 end
            end

            return count
        end

        local createVertRoute = cmd.Accept("create-vertical-route",
            ---@param data {commandValue:string, distance:number, followGravInAtmo:boolean, extraPointMargin:number, x:number, y:number, z:number}
            function(data)
                local partCount = countProvidedVectorParts(data)
                local dir ---type @Vec3

                if partCount == 0 then
                    dir = -universe.VerticalReferenceVector()
                elseif partCount ~= 3 then
                    log:Error("Either none or all three vector components must be provided")
                    return
                else
                    dir = Vec3.New(data.x, data.y, data.z)
                end

                local route = rc.CreateRoute(data.commandValue)
                if route then
                    local startPos = route.AddCurrentPos()
                    startPos.Options().Set(PointOptions.LOCK_DIRECTION, Forward())

                    local targetPos = Current() + dir * data.distance

                    local startBody = universe.ClosestBody(Current())
                    local startInAtmo = startBody:IsInAtmo(Current())
                    local bodyClosestToEnd = universe.ClosestBody(targetPos)
                    local endInAtmo = bodyClosestToEnd:IsInAtmo(targetPos)

                    if data.followGravInAtmo then
                        if startInAtmo and endInAtmo then
                            log:Warning(
                                "Start and end point are in atmosphere, skipping additional gravity-aligned point in space.")
                        elseif endInAtmo and not startInAtmo then
                            log:Error(
                                "Cannot calculate extra gravity aligned point when start point is not within atmosphere")
                            return
                        elseif startInAtmo and not endInAtmo then
                            local pointInSpace = Current() -
                                VerticalReferenceVector() * startBody:DistanceToAtmoEdge(Current())
                            -- Add a precentage of the distance between target and atmosphere edge
                            local diff = (pointInSpace - targetPos):Len() * 0.05
                            pointInSpace = pointInSpace - VerticalReferenceVector() * diff
                            local extra = route.AddCoordinate(pointInSpace)
                            extra.Options().Set(PointOptions.LOCK_DIRECTION, Forward())
                            extra.Options().Set(PointOptions.MARGIN, data.extraPointMargin)
                            log:Info("Added extra gravity-aligned point in space at ",
                                extra.Pos(), "with a margin of ", data.extraPointMargin, "m")
                        end
                    end

                    local endPos = route.AddCoordinate(targetPos)
                    endPos.Options().Set(PointOptions.LOCK_DIRECTION, Forward())

                    if rc.SaveRoute() then
                        log:Info("Created a route by name '", data.commandValue,
                            "' with start at current position and direction with the endpoint at ", endPos.Pos())
                    else
                        log:Error("Could not create the route")
                    end
                end
            end).AsString().Mandatory()
        createVertRoute.Option("distance").AsNumber().Mandatory()
        createVertRoute.Option("followGravInAtmo").AsEmptyBoolean()
        createVertRoute.Option("extraPointMargin").AsNumber().Default(5)
        createVertRoute.Option("x").AsNumber()
        createVertRoute.Option("y").AsNumber()
        createVertRoute.Option("z").AsNumber()

        cmd.Accept("print-vertical-up", function(_)
            local up = -universe.VerticalReferenceVector()
            log:Info(string.format("-x %0.14f -y %0.14f -z %0.14f", up.x, up.y, up.z))
        end)

        cmd.Accept("floor",
            ---@param data {commandValue:string}
            function(data)
                screenCtrl.ActivateFloorMode(data.commandValue)
            end).AsString().Mandatory()
    end

    function s.RegisterMoveCommands()
        local moveFunc = function(data)
            local route = rc.ActivateTempRoute()
            local pos = Current()
            local point = route.AddCoordinate(pos + vehicle.orientation.Forward() * data.f +
                vehicle.orientation.Right() * data.r - universe.VerticalReferenceVector() * data.u)
            point.SetOptions(createOptions(data))
            log:Info("Moving to ", point.Pos())

            flightCore.StartFlight()
        end

        local moveCmd = cmd.Accept("move", moveFunc)
        moveCmd.Option("-u").AsNumber().Mandatory().Default(0)
        moveCmd.Option("-r").AsNumber().Mandatory().Default(0)
        moveCmd.Option("-f").AsNumber().Mandatory().Default(0)
        addPointOptions(moveCmd)

        local turnFunc = function(data)
            -- Turn in the expected way, i.e. clockwise on positive values.
            local angle = -data.commandValue
            flightCore.Turn(angle, Up())
        end

        cmd.Accept("turn", turnFunc).AsNumber()

        local strafeFunc = function(data)
            local route = rc.ActivateTempRoute()
            local point = route.AddCoordinate(Current() +
                vehicle.orientation.Right() * data.commandValue)
            local p = point.Options()
            p.Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():Unpack() })
            p.Set(PointOptions.MAX_SPEED, data.maxspeed or vehicle.speed.MaxSpeed())

            flightCore.StartFlight()
        end

        local strafeCmd = cmd.Accept("strafe", strafeFunc).AsNumber()
        strafeCmd.Option("-maxspeed").AsNumber()

        ---@param userInput string
        ---@return {pos: string, coord:Vec3}|nil
        local function getPos(userInput)
            local target
            local point = rc.LoadWaypoint(userInput)
            if point then
                target = { pos = point.Pos(), coord = universe.ParsePosition(point.Pos()).Coordinates() }
            else
                local pos = universe.ParsePosition(userInput)
                if pos then
                    target = { pos = pos.AsPosString(), coord = pos.Coordinates() }
                end
            end

            if not target then
                log:Error("Given input is not a :pos{} string or a named waypoint")
            end

            return target
        end

        local gotoCmd = cmd.Accept("goto",
            ---@param data {commandValue:string, lockdir:boolean, maxspeed:number, margin:number, offset:number}
            function(data)
                local target = getPos(data.commandValue)

                if target then
                    local direction, distance = (target.coord - Current()):NormalizeLen()
                    local remaining = distance - data.offset

                    local offsetTarget
                    if remaining > 0 then
                        offsetTarget = Current() + direction * remaining
                    else
                        offsetTarget = target.coord
                    end

                    local lockToDir = Vec3.zero
                    if data.lockdir then
                        lockToDir = Forward()
                    end
                    flightCore.GotoTarget(offsetTarget, lockToDir, data.margin, data.maxspeed, 0, false)
                    log:Info("Moving to ", universe.CreatePos(offsetTarget).AsPosString())
                end
            end).AsString().Mandatory()
        addPointOptions(gotoCmd)
        gotoCmd.Option("offset").AsNumber().Default(0)

        ---@param pos Position|nil
        local function alignTo(pos)
            if pos then
                local route = rc.ActivateTempRoute()
                route.AddCurrentPos()
                flightCore.StartFlight()
                flightCore.AlignTo(pos.Coordinates())
                log:Info("Aligning to ", pos.AsPosString())
            end
        end

        cmd.Accept("align-to",
            ---@param data {commandValue:string}
            function(data)
                local target = getPos(data.commandValue)
                if target then
                    local pos = universe.ParsePosition(target.pos)
                    alignTo(pos)
                end
            end).AsString().Mandatory()

        local aligntToVector = cmd.Accept("align-to-vector",
            ---@param data {x:number, y:number, z:number}
            function(data)
                local pos = universe.CreatePos(Current() + Vec3.New(data.x, data.y, data.z))
                alignTo(pos)
            end)

        aligntToVector.Option("x").AsNumber().Mandatory()
        aligntToVector.Option("y").AsNumber().Mandatory()
        aligntToVector.Option("z").AsNumber().Mandatory()

        cmd.Accept("set-waypoint",
            ---@param data {commandValue:string, notify:boolean}
            function(data)
                system.setWaypoint(data.commandValue, data.notify)
            end).AsString()
            .Option("notify").AsEmptyBoolean()
    end

    return setmetatable(s, ControlCommands)
end

return ControlCommands
