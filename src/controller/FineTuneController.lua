local Criteria     = require("input/Criteria")
local PointOptions = require("flight/route/PointOptions")
local log          = require("debug/Log")()
local vehicle      = require("abstraction/Vehicle").New()
local calc         = require("util/Calc")
local universe     = require("universe/Universe").Instance()
local keys         = require("input/Keys")

---@class FineTuneController

local FineTuneController = {}
FineTuneController.__index = FineTuneController

---@param input Input
---@param cmd CommandLine
---@param flightCore FlightCore
---@return ControlInterface
function FineTuneController.New(input, cmd, flightCore)
    local s = {}
    local step = 0.1
    local rc = flightCore.GetRouteController()

    ---Initiates a movement
    ---@param reference vec3
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

    function s.Setup()
        player.freeze(true)

        input.Register(keys.forward, Criteria.New().OnRepeat(), function()
            move(vehicle.orientation.Forward(), step)
        end)

        input.Register(keys.backward, Criteria.New().OnRepeat(), function()
            move(vehicle.orientation.Forward(), -step)
        end)

        input.Register(keys.strafeleft, Criteria.New().OnRepeat(), function()
            local options = PointOptions.New()
            options.Set(PointOptions.MAX_SPEED, speed)
            options.Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():unpack() })

            move(-vehicle.orientation.Right(), step, options)
        end)

        input.Register(keys.straferight, Criteria.New().OnRepeat(), function()
            local options = PointOptions.New()
            options.Set(PointOptions.MAX_SPEED, speed)
            options.Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():unpack() })
            move(vehicle.orientation.Right(), step, options)
        end)

        input.Register(keys.up, Criteria.New().OnRepeat(), function()
            move(-universe.VerticalReferenceVector(), step)
        end)

        input.Register(keys.down, Criteria.New().OnRepeat(), function()
            move(-universe.VerticalReferenceVector(), -step)
        end)

        input.Register(keys.yawleft, Criteria.New().OnRepeat(), function()
            flightCore.Turn(1, vehicle.orientation.Up())
        end)

        input.Register(keys.yawright, Criteria.New().OnRepeat(), function()
            flightCore.Turn(-1, vehicle.orientation.Up())
        end)
    end

    function s.TearDown()
        player.freeze(false)
        input.Clear()
        cmd.Clear()
    end

    return setmetatable(s, FineTuneController)
end

return FineTuneController
