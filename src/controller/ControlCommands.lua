---@module "commandline/CommandLine"
---@module "input/Input"

local Criteria                = require("input/Criteria")
local PointOptions            = require("flight/route/PointOptions")
local Vec3                    = require("math/Vec3")
local Waypoint                = require("flight/Waypoint")
local log                     = require("debug/Log").Instance()
local vehicle                 = require("abstraction/Vehicle").New()
local brakes                  = require("flight/Brakes").Instance()
local calc                    = require("util/Calc")
local universe                = require("universe/Universe").Instance()
local keys                    = require("input/Keys")
local pub                     = require("util/PubSub").Instance()
local constants               = require("YFSConstants")
local gateCtrl                = require("controller/GateControl").Instance()
local radar                   = require("element/Radar").Instance()
local VerticalReferenceVector = universe.VerticalReferenceVector
local Current                 = vehicle.position.Current
local Forward                 = vehicle.orientation.Forward
local Right                   = vehicle.orientation.Right
local Up                      = vehicle.orientation.Up

---@alias PointOptionArguments { commandValue:string, maxspeed:number, margin:number, lockdir:boolean}

---@class ControlCommands
---@field New fun(input:Input, cmd:Command, flightCore:FlightCore)
---@field RegisterCommonCommands fun(isECU:boolean)
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
---@param access Access
---@return ControlCommands
function ControlCommands.New(input, cmd, flightCore, settings, screenCtrl, access)
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
        c.Option("-forceVerticalUp").AsBoolean().Default(true)
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

    ---@param isECU boolean
    function s.RegisterCommonCommands(isECU)
        -- Setup brakes
        if not isECU then
            input.Register(keys.brake, Criteria.New().OnPress(), function() brakes.Forced(true) end)
            input.Register(keys.brake, Criteria.New().OnRelease(), function() brakes.Forced(false) end)
        end

        cmd.Accept("idle", function(data)
            log.Info("Going idle!")
            flightCore.GoIdle()
        end)

        cmd.Accept("hold", function(data)
            holdPosition()
        end)

        cmd.Accept("print-pos", function(_)
            log.Info("Current pos:", universe.CreatePos(Current()):AsPosString())
            log.Info("Alignment pos:",
                universe.CreatePos(Current() + vehicle.orientation.Forward() * Waypoint.DirectionMargin):AsPosString())
        end)


        local lastWidget = settings.Boolean("showWidgetsOnStart", false)

        input.Register(keys.option8, Criteria.New().LShift().OnPress(), function()
            lastWidget = not lastWidget
            pub.Publish("ShowInfoWidgets", lastWidget)
        end)

        input.Register(keys.option7, Criteria.New().LShift().OnPress(), function()
            radar.Show(not radar.IsVisible())
        end)

        input.Register(keys.option7, Criteria.New().OnPress(), function()
            radar.NextMethod()
        end)
    end

    ---Get the route being edited
    ---@return Route|nil
    local function getEditRoute()
        local route = rc.CurrentEdit()
        if route == nil then
            log.Error("No route being edited")
        end

        return route
    end

    function s.RegisterRouteCommands()
        cmd.Accept("route-list", function(data)
            local routes = rc.GetRouteNames()
            log.Info(#routes, " available routes")
            for _, r in ipairs(routes) do
                log.Info(r)
            end
        end)

        cmd.Accept("route-edit",
            ---@param data {commandValue:string}
            function(data)
                if rc.EditRoute(data.commandValue) then
                    log.Info("Route open for edit")
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

        local renameRoute = cmd.Accept("route-rename",
            ---@param data {from:string, to:string}
            function(data)
                rc.RenameRoute(data.from, data.to)
            end).AsEmpty()
        renameRoute.Option("from").AsString().Mandatory()
        renameRoute.Option("to").AsString().Mandatory()

        cmd.Accept("route-print", function(data)
            local route = getEditRoute()
            if route == nil then
                return
            end

            for i, p in ipairs(route.Points()) do
                log.Info(i, ":", calc.Ternary(p.HasWaypointRef(), p.WaypointRef(), p.Pos()))

                local opts = p.Options()
                for k, v in pairs(opts.Data()) do
                    log.Info("- ", k, ": ", v)
                end
            end
        end)

        cmd.Accept("route-activate",
            ---@param data {commandValue:string, index:number}
            function(data)
                if not access.MayStartRoute(data.commandValue) then
                    return
                end

                if rc.ActivateRoute(data.commandValue, data.index,
                        settings.Number("routeStartDistanceLimit"),
                        settings.Number("openGateMaxDistance")) then
                    gateCtrl.Enable(true)
                    flightCore.StartFlight()
                    pub.Publish("ResetWSAD", true)
                    log.Info("Flight started")
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
                log.Info("Added current position to route")
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
                        log.Info("Added position to route")
                    else
                        log.Error("Could not add postion")
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
                    log.Info("Point removed")
                else
                    log.Error("Could not remove point")
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
                log.Info("Point moved:", from, " to ", to)
            else
                log.Error("Could not move point")
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
                log.Info("Margins on all points in route set to ", data.commandValue)
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
                log.Info("Max speeds on all points in route set to ", data.commandValue, "km/h")
            end).AsNumber().Mandatory()

        local cmdSetPosOption = cmd.Accept("route-set-pos-option",
            ---@param data {ix:number, endIx:number, toggleSkippable:boolean, toggleSelectable:boolean, margin:boolean, finalSpeed:number, maxSpeed:number, toggleGate:boolean}
            function(data)
                local route = getEditRoute()
                if route == nil then
                    return
                end

                if not data.endIx then
                    data.endIx = data.ix
                end

                if data.maxSpeed and data.maxSpeed < 0 then
                    log.Error("Max speed must be larger than 0")
                    return
                end

                if data.ix > data.endIx then
                    log.Error("Start index must be less or equal to end index")
                    return
                end

                if not (route.CheckBounds(data.ix) and route.CheckBounds(data.endIx)) then
                    log.Error("Index out of bounds")
                    return
                end

                if data.margin and data.margin < 0.1 then
                    log.Error("Margin must be larger or equal to 0.1m")
                    return
                end

                if data.finalSpeed and data.finalSpeed < 0 then
                    log.Error("Final speed must be >= 0")
                    return
                end

                log.Info("Setting point options for point indexes ", data.ix, " through ", data.endIx)

                for i = data.ix, data.endIx, 1 do
                    if data.toggleSkippable then
                        local newValue = not route.GetPointOption(i, PointOptions.SKIPPABLE, false)
                        if route.SetPointOption(i, PointOptions.SKIPPABLE, newValue) then
                            log.Info("Set skippable option to ", newValue)
                        end
                    end

                    if data.toggleSelectable then
                        local newValue = not route.GetPointOption(i, PointOptions.SELECTABLE, true)
                        if route.SetPointOption(i, PointOptions.SELECTABLE, newValue) then
                            log.Info("Set selectable option to ", newValue)
                        end
                    end

                    if data.margin then
                        route.SetPointOption(i, PointOptions.MARGIN, data.margin)
                    end

                    if data.finalSpeed then
                        route.SetPointOption(i, PointOptions.FINAL_SPEED, calc.Kph2Mps(data.finalSpeed))
                    end

                    if data.maxSpeed then
                        route.SetPointOption(i, PointOptions.MAX_SPEED, calc.Kph2Mps(data.maxSpeed))
                    end

                    if data.toggleGate then
                        local newValue = not route.GetPointOption(i, PointOptions.GATE, false)
                        route.SetPointOption(i, PointOptions.GATE, newValue)
                        log.Info("Set gate option to ", newValue)
                    end
                end
            end).AsEmpty()
        cmdSetPosOption.Option("ix").AsNumber().Mandatory()
        cmdSetPosOption.Option("endIx").AsNumber()
        cmdSetPosOption.Option("toggleSkippable").AsEmptyBoolean()
        cmdSetPosOption.Option("toggleSelectable").AsEmptyBoolean()
        cmdSetPosOption.Option("margin").AsNumber()
        cmdSetPosOption.Option("finalSpeed").AsNumber()
        cmdSetPosOption.Option("maxSpeed").AsNumber()
        cmdSetPosOption.Option("toggleGate").AsEmptyBoolean()

        cmd.Accept("route-print-pos-options",
            ---@param data {commandValue:number}
            function(data)
                local route = getEditRoute()
                if route == nil then
                    return
                end

                for i, k in ipairs(PointOptions.ALL) do
                    local val = route.GetPointOption(data.commandValue, k, nil)
                    if val ~= nil then
                        log.Info(k, ": ", val)
                    end
                end
            end).AsNumber()

        local saveCurrAs = cmd.Accept("pos-save-current-as",
            ---@param data {name:string, auto:boolean}
            function(data)
                if data.auto then
                    local new = rc.FirstFreeWPName()
                    if not new then
                        log.Error("Could not find a free waypoint name")
                        return
                    end

                    data.name = new
                elseif not data.name then
                    log.Error("No name provided")
                end

                local pos = universe.CreatePos(Current()).AsPosString()
                rc.StoreWaypoint(data.name, pos)
            end).AsEmpty()
        saveCurrAs.Option("name").AsString()
        saveCurrAs.Option("auto").AsEmptyBoolean()

        cmd.Accept("pos-save-as",
            ---@param data {commandValue:string, pos:string}
            function(data)
                local p = universe.ParsePosition(data.pos)
                if p then
                    if rc.StoreWaypoint(data.commandValue, p.AsPosString()) then
                        log.Info("Current position saved as ", data.commandValue)
                    end
                end
            end).AsString().Mandatory().Option("pos").AsString().Mandatory()

        cmd.Accept("pos-list", function(_)
            for _, data in ipairs(rc.GetWaypoints()) do
                log.Info(data.name, ": ", data.point:Pos())
            end
        end)

        local rename = cmd.Accept("pos-rename",
            ---@param data {old:string, new:string}
            function(data)
                rc.RenameWaypoint(data.old, data.new)
            end)
        rename.Option("old").Mandatory().AsString()
        rename.Option("new").Mandatory().AsString()

        cmd.Accept("pos-delete",
            ---@param data {commandValue:string}
            function(data)
                local deleted = rc.DeleteWaypoint(data.commandValue)
                if deleted then
                    log.Info("Deleted waypoint: '", data.commandValue, "', position was ", deleted.pos)
                end
            end).AsString().Mandatory()

        local alongGrav = cmd.Accept("pos-create-along-gravity",
            ---@param data {commandValue:string, u:number}
            function(data)
                local pos = Current() - universe.VerticalReferenceVector() * data.u
                local posStr = universe.CreatePos(pos).AsPosString()
                if rc.StoreWaypoint(data.commandValue, posStr) then
                    log.Info("Stored postion ", posStr, " as ", data.commandValue)
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
                    log.Error("Must provide atleast one direction distance")
                else
                    local pos = Current() + Forward() * f + Right() * r + Up() * u
                    local posStr = universe.CreatePos(pos).AsPosString()
                    if rc.StoreWaypoint(data.commandValue, posStr) then
                        log.Info("Stored postion ", posStr, " as ", data.commandValue)
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
                    log.Error("Must provide atleast one direction distance")
                else
                    local pos = Current() + Forward() * f + Right() * r + Up() * u
                    local posStr = universe.CreatePos(pos).AsPosString()
                    log.Info("Position is at: ", posStr)
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
                    log.Error("Either none or all three vector components must be provided")
                    return
                else
                    dir = Vec3.New(data.x, data.y, data.z)
                end

                local route = rc.CreateRoute(data.commandValue)
                if route then
                    local startPos = route.AddCurrentPos()
                    local startOpt = startPos.Options()
                    startOpt.Set(PointOptions.LOCK_DIRECTION, Forward())
                    startOpt.Set(PointOptions.MARGIN, constants.flight.defaultStartEndMargin)

                    local targetPos = Current() + dir * data.distance

                    local startBody = universe.ClosestBody(Current())
                    local startInAtmo = startBody:IsInAtmo(Current())
                    local bodyClosestToEnd = universe.ClosestBody(targetPos)
                    local endInAtmo = bodyClosestToEnd:IsInAtmo(targetPos)

                    if data.followGravInAtmo then
                        if startInAtmo and endInAtmo then
                            log.Warning(
                                "Start and end point are in atmosphere, skipping additional gravity-aligned point in space.")
                        elseif endInAtmo and not startInAtmo then
                            log.Error(
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
                            log.Info("Added extra gravity-aligned point in space at ",
                                extra.Pos(), "with a margin of ", data.extraPointMargin, "m")
                        end
                    end

                    local endPos = route.AddCoordinate(targetPos)
                    local endOpt = endPos.Options()
                    endOpt.Set(PointOptions.LOCK_DIRECTION, Forward())
                    endOpt.Set(PointOptions.MARGIN, constants.flight.defaultStartEndMargin)

                    if rc.SaveRoute() then
                        log.Info("Created a route by name '", data.commandValue,
                            "' with start at current position and direction with the endpoint at ", endPos.Pos())
                    else
                        log.Error("Could not create the route")
                    end
                end
            end).AsString().Mandatory()
        createVertRoute.Option("distance").AsNumber().Mandatory()
        createVertRoute.Option("followGravInAtmo").AsEmptyBoolean()
        createVertRoute.Option("extraPointMargin").AsNumber().Default(5)
        createVertRoute.Option("x").AsNumber()
        createVertRoute.Option("y").AsNumber()
        createVertRoute.Option("z").AsNumber()

        ---@param v Vec3
        local function formatVecParts(v)
            return string.format("-x %0.14f -y %0.14f -z %0.14f", v.x, v.y, v.z)
        end

        cmd.Accept("print-vertical-up", function(_)
            log.Info(formatVecParts(-universe.VerticalReferenceVector()))
        end)

        local sub = cmd.Accept("sub-pos",
            ---@param data  {commandValue:string, sub:string|nil}
            function(data)
                local sub
                if data.sub then
                    local subPos = universe.ParsePosition(data.sub)
                    if not subPos then
                        return
                    end

                    sub = subPos.Coordinates()
                else
                    log.Info("No subtrahend specified, using current position")
                    sub = Current()
                end

                local pos = universe.ParsePosition(data.commandValue)
                if pos then
                    local diff = pos.Coordinates() - sub
                    local dir, dist = diff:NormalizeLen()
                    log.Info("-distance ", dist, " ", formatVecParts(dir))
                end
            end).AsString().Mandatory()
        sub.Option("-sub").AsString()

        local closestOnLine = cmd.Accept("closest-on-line",
            ---@param data {a:string, b:string}
            function(data)
                local p1 = universe.ParsePosition(data.a)
                local p2 = universe.ParsePosition(data.b)

                if not (p1 and p2) then
                    return
                end

                local p = calc.NearestPointOnLine(p1.Coordinates(),
                    (p1.Coordinates() - p2:Coordinates()):NormalizeInPlace(), Current())
                local closest = universe.CreatePos(p)
                log.Info("Closest point on the line passing through a and b is at ", closest.AsPosString())
            end)
        closestOnLine.Option("a").AsString().Mandatory()
        closestOnLine.Option("b").AsString().Mandatory()

        cmd.Accept("get-parallel-from-route",
            ---@param data {commandValue:string}
            function(data)
                local r = rc.LoadRoute(data.commandValue)
                if not r then
                    return
                end

                local points = r.Points()
                if #points < 2 then
                    log.Error("Only one point in route, can't make a parallel point from that.")
                end

                local second = universe.ParsePosition(points[2].Pos()):Coordinates()
                local first = universe.ParsePosition(points[1].Pos()):Coordinates()
                local diff = second - first

                local dir, dist = diff:NormalizeLen()
                log.Info("-distance ", dist, " ", formatVecParts(dir))
            end).AsString().Mandatory()


        cmd.Accept("floor",
            ---@param data {commandValue:string}
            function(data)
                screenCtrl.ActivateFloorMode(data.commandValue)
            end).AsString().Mandatory()
    end

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
            log.Error("Given input is not a :pos{} string or a named waypoint")
        end

        return target
    end

    ---@param target Vec3
    ---@param lockDir boolean
    ---@param maxSpeed number
    ---@param margin number
    ---@param forceVerticalUp boolean
    local function executeMove(target, lockDir, maxSpeed, margin, forceVerticalUp)
        if maxSpeed ~= 0 then
            maxSpeed = calc.Kph2Mps(maxSpeed)
        end

        local lockToDir = Vec3.zero
        if lockDir then
            lockToDir = Forward()
        end

        gateCtrl.Enable(false)
        flightCore.GotoTarget(target, lockToDir, margin, maxSpeed, 0, false, forceVerticalUp)
        pub.Publish("ResetWSAD", true)
        log.Info("Moving to ", universe.CreatePos(target).AsPosString())
    end

    function s.RegisterMoveCommands()
        ---@param data {commandValue:string, lockdir:boolean, maxspeed:number, margin:number, u:number, r:number, f:number, forceVerticalUp:boolean}
        local moveFunc = function(data)
            local target = Current() + vehicle.orientation.Forward() * data.f + vehicle.orientation.Right() * data.r -
                universe.VerticalReferenceVector() * data.u

            executeMove(target, data.lockdir, data.maxspeed, data.margin, data.forceVerticalUp)
        end

        local moveCmd = cmd.Accept("move", moveFunc)
        moveCmd.Option("-u").AsNumber().Mandatory().Default(0)
        moveCmd.Option("-r").AsNumber().Mandatory().Default(0)
        moveCmd.Option("-f").AsNumber().Mandatory().Default(0)
        addPointOptions(moveCmd)

        local gotoCmd = cmd.Accept("goto",
            ---@param data {commandValue:string, lockdir:boolean, maxspeed:number, margin:number, offset:number, forceVerticalUp:boolean}
            function(data)
                local target = getPos(data.commandValue)

                if target then
                    -- A negative offset means on the other side of the point
                    local direction, distance = (target.coord - Current()):NormalizeLen()
                    local remaining = distance - data.offset

                    if remaining > 0 then
                        executeMove(Current() + direction * remaining, data.lockdir, data.maxspeed, data.margin,
                            data.forceVerticalUp)
                    else
                        log.Error("Offset larger than distance to target")
                    end
                end
            end).AsString().Mandatory()
        addPointOptions(gotoCmd)
        gotoCmd.Option("offset").AsNumber().Default(0)

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

        ---@param pos Position|nil
        local function alignTo(pos)
            if pos then
                local route = rc.ActivateTempRoute()
                route.AddCurrentPos()
                flightCore.StartFlight()
                flightCore.AlignTo(pos.Coordinates())
                log.Info("Aligning to ", pos.AsPosString())
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

        local alignToVector = cmd.Accept("align-to-vector",
            ---@param data {x:number, y:number, z:number}
            function(data)
                local pos = universe.CreatePos(Current() + Vec3.New(data.x, data.y, data.z))
                alignTo(pos)
            end)

        alignToVector.Option("x").AsNumber().Mandatory()
        alignToVector.Option("y").AsNumber().Mandatory()
        alignToVector.Option("z").AsNumber().Mandatory()

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
