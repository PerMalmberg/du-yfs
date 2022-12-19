local Criteria     = require("input/Criteria")
local PointOptions = require("flight/route/PointOptions")
local log          = require("debug/Log")()
local vehicle      = require("abstraction/Vehicle").New()
local calc         = require("util/Calc")
local universe     = require("universe/Universe").Instance()
local keys         = require("input/Keys")
local Clamp        = calc.Clamp

---@class FineTuneController

local FineTuneController = {}
FineTuneController.__index = FineTuneController

---@param input Input
---@param cmd CommandLine
---@param flightCore FlightCore
---@return ControlInterface
function FineTuneController.New(input, cmd, flightCore)
    local s = {}
    local movestep = 0.1
    local turnAngle = 1
    local speed = construct.getMaxSpeed()
    local rc = flightCore.GetRouteController()

    ---Initiates a movement
    ---@param reference Vec3
    ---@param distance number
    ---@param options PointOptions|nil
    local function move(reference, distance, options)
        local route = rc.ActivateTempRoute()
        local point = route.AddCoordinate(vehicle.position.Current() + reference * distance)
        local opt = options or point.Options()

        opt.Set(PointOptions.MAX_SPEED, speed)
        opt.Set(PointOptions.FINAL_SPEED, 0) -- Move and come to a stop

        point.SetOptions(opt)

        flightCore.StartFlight()
    end

    local function printCurrent()
        log:Info("Turn angle: ", turnAngle, "°, step: ", movestep, "m, speed: ", speed, "km/h")
    end

    function s.Setup()
        player.freeze(true)

        input.Register(keys.forward, Criteria.New().OnRepeat(), function()
            move(vehicle.orientation.Forward(), movestep)
        end)

        input.Register(keys.backward, Criteria.New().OnRepeat(), function()
            move(vehicle.orientation.Forward(), -movestep)
        end)

        input.Register(keys.strafeleft, Criteria.New().OnRepeat(), function()
            local options = PointOptions.New()
            options.Set(PointOptions.MAX_SPEED, speed)
            options.Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():Unpack() })

            move(-vehicle.orientation.Right(), movestep, options)
        end)

        input.Register(keys.straferight, Criteria.New().OnRepeat(), function()
            local options = PointOptions.New()
            options.Set(PointOptions.MAX_SPEED, speed)
            options.Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():Unpack() })
            move(vehicle.orientation.Right(), movestep, options)
        end)

        input.Register(keys.up, Criteria.New().OnRepeat(), function()
            move(-universe.VerticalReferenceVector(), movestep)
        end)

        input.Register(keys.down, Criteria.New().OnRepeat(), function()
            move(-universe.VerticalReferenceVector(), -movestep)
        end)

        input.Register(keys.yawleft, Criteria.New().OnRepeat(), function()
            flightCore.Turn(turnAngle, vehicle.orientation.Up())
        end)

        input.Register(keys.yawright, Criteria.New().OnRepeat(), function()
            flightCore.Turn(-turnAngle, vehicle.orientation.Up())
        end)

        cmd.Accept("step", function(data)
            movestep = Clamp(data.commandValue, 0.1, 200000)
            printCurrent()
        end).AsNumber().Mandatory()

        cmd.Accept("speed", function(data)
            speed = calc.Kph2Mps(Clamp(data.commandValue, 1, calc.Mps2Kph(construct.getMaxSpeed())))
            printCurrent()
        end).AsNumber().Mandatory()

        cmd.Accept("turn-angle", function(data)
            turnAngle = Clamp(data.commandValue, 0, 360)
            printCurrent()
        end)

        ---@param c Command
        local function addPointOptions(c)
            c.Option("-precision").AsBoolean().Default(false)
            c.Option("-lockdir").AsBoolean().Default(false)
            c.Option("-maxspeed").AsNumber().Default(speed)
            c.Option("-margin").AsNumber().Default(0.1)
        end

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

        local moveFunc = function(data)
            local route = rc.ActivateTempRoute()
            local pos = vehicle.position.Current()
            local point = route.AddCoordinate(pos + vehicle.orientation.Forward() * data.f +
                vehicle.orientation.Right() * data.r - universe.VerticalReferenceVector() * data.u)
            point.SetOptions(createOptions(data))

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

            flightCore.Turn(angle, vehicle.orientation.Up())
        end

        cmd.Accept("turn", turnFunc).AsNumber()

        local strafeFunc = function(data)
            local route = rc.ActivateTempRoute()
            local point = route.AddCoordinate(vehicle.position.Current() +
                vehicle.orientation.Right() * data.commandValue)
            local p = PointOptions.New()
            point.options = p
            p.Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():Unpack() })
            p.Set(PointOptions.MAX_SPEED, data.maxspeed or speed)

            flightCore.StartFlight()
        end

        local strafeCmd = cmd.Accept("strafe", strafeFunc).AsNumber()
        strafeCmd.Option("-maxspeed").AsNumber()

        local gotoCmd = cmd.Accept("goto",
            ---@param data {commandValue:string}
            function(data)
                local target
                local point = rc.LoadWaypoint(data.commandValue)
                if point then
                    target = point.Pos()
                else
                    local pos = universe.ParsePosition(data.commandValue)
                    if pos then
                        target = pos.AsPosString()
                    end
                end

                if target then
                    local route = rc.ActivateTempRoute()
                    route.AddCurrentPos()
                    local targetPoint = route.AddPos(target)
                    targetPoint.SetOptions(createOptions(data))
                    flightCore.StartFlight()
                    log:Info("Moving to position")
                else
                    log:Error("Given position is not a :pos{} string or a named waypoint")
                end
            end).AsString().Mandatory()
        addPointOptions(gotoCmd)

        printCurrent()
        log:Info("Player locked in place")
    end

    function s.TearDown()
        player.freeze(false)
        log:Info("Player released")
        input.Clear()
        cmd.Clear()
    end

    return setmetatable(s, FineTuneController)
end

return FineTuneController
