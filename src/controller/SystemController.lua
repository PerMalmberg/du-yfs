local RouteModeController = require("controller/RouteModeController")
local FineTuneController  = require("controller/FineTuneController")
local Criteria            = require("input.Criteria")
local Task                = require("system/Task")
local log                 = require("debug/Log")()
local pub                 = require("util/PubSub").Instance()
local sharedPanel         = require("panel/SharedPanel")()
local commandLine         = require("commandline/CommandLine").Instance()
local input               = require("input/Input").Instance()
local keys                = require("input/Keys")
local brakes              = require("Brakes").Instance()

---@module "controller/ControlInterface"

---@enum FlightMode
FlightMode = {
    Route = 1,
    -- FreeFlight = 2,
    FineTune = 3
}

---@class SystemController
---@field SetMode fun(mode:FlightMode)

local SystemController = {}
SystemController.__index = SystemController

---@param flightCore FlightCore
---@return SystemController
function SystemController.New(flightCore)
    local s = {}
    local mode = FlightMode.Route ---@type FlightMode
    local ifc ---@type ControlInterface

    local routeController = flightCore.GetRouteController()

    local function holdPosition()
        local r = routeController.ActivateTempRoute()
        r.AddCurrentPos()
        flightCore.StartFlight()
    end

    local function screenTask()
        local screen = library.getLinkByClass("ScreenUnit")

        while screen do
            coroutine.yield()
            -- Get data to send to screen

            -- Send data to screen

            -- Get data from screen

            -- Publish data to system

        end
    end

    local function setupRouteMode()
        -- Follows a route from start to end.
        -- Takes input from screen
        -- Takes input from command line
        log:Info("Mode: Route")
        ifc = RouteModeController.New(input, commandLine, flightCore)
        ifc.Setup()
    end

    local function setupFreeFlightMode()
        --[[ Moves in the direction the player looks, as long as a button is held.
            Needed functionality
            - Altitude hold
            - Speed control
            - Landing assist "press G"
        ]]
        log:Info("Mode: Free Flight - Not yet implemented")
    end

    local function setupFineTuneMode()
        -- Moves from point A to B, always stopping at B.
        log:Info("Mode: Fine Tuning")
        ifc = FineTuneController.New(input, commandLine, flightCore)
        ifc.Setup()
    end

    local function switchMode()
        --mode = FlightMode.Route + (mode % FlightMode.FineTune)
        if mode == FlightMode.FineTune then
            s.SetMode(FlightMode.Route)
        else
            s.SetMode(FlightMode.Route)
        end
    end

    local function registerCommonControls()
        -- shift + alt + Option9 to switch modes
        input.Register(keys.option9, Criteria.New().LAlt().LShift().OnPress(), switchMode)

        -- Setup brakes
        input.Register(keys.brake, Criteria.New().OnPress(), function() brakes:Forced(true) end)
        input.Register(keys.brake, Criteria.New().OnRelease(), function() brakes:Forced(false) end)
    end

    ---Sets new operational mode
    ---@param newMode FlightMode
    function s.SetMode(newMode)
        if mode ~= newMode then
            mode = newMode
            holdPosition()

            if ifc then ifc.TearDown() end
            input.Clear()

            if mode == FlightMode.Route then
                setupRouteMode()
            elseif mode == FlightMode.FreeFlight then
                setupFreeFlightMode()
            else
                setupFineTuneMode()
            end

            registerCommonControls()
        end
    end

    -- Create a Task to handle communication with the screen
    Task.New("ControllScreen", screenTask)
        .Then(function(...)
            log:Info("No screen connected")
        end).Catch(function(t)
            log:Error(t.Error())
        end)

    -- Register for events from the flight system
    -- All the things currently in widgets

    return setmetatable(s, SystemController)
end

return SystemController
