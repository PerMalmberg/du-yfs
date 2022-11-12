local r = require("CommonRequire")
local keys = require("input/Keys")
local Criteria = require("input/Criteria")
local PointOptions = require("flight/route/PointOptions")
local CommandLine = require("commandline/CommandLine")
local Input = require("input/Input")
local utils = r.utils

local log = r.log
local vehicle = r.vehicle
local calc = r.calc
local universe = r.universe

---@module "flight/FlightCore"

---@class InputHandler
---@field New fun(flightCore.FlightCore):InputHandler

local InputHandler = {}
InputHandler.__index = InputHandler

---Creates a new InputHandler
---@param flightCore FlightCore
---@return InputHandler
function InputHandler.New(flightCore)
    local s = {}

    local step = 50
    local speed = calc.Kph2Mps(150)

    local routeController = flightCore.GetRouteController()
    local cmd = CommandLine.Instance()



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
        local route = routeController.ActivateTempRoute()
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
        local route = routeController.ActivateTempRoute()
        local point = route.AddCoordinate(vehicle.position.Current() + vehicle.orientation.Right() * data.commandValue)
        local p = PointOptions.New()
        point.options = p
        p.Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():Unpack() })
        p.Set(PointOptions.MAX_SPEED, data.maxspeed or speed)

        flightCore.StartFlight()
    end

    local strafeCmd = cmd.Accept("strafe", strafeFunc).AsNumber()
    strafeCmd.Option("-maxspeed").AsNumber()

    return setmetatable(s, InputHandler)
end

return InputHandler
