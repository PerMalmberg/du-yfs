local pub                 = require("util/PubSub").Instance()
local sharedPanel         = require("panel/SharedPanel")()
local commandLine         = require("commandline/CommandLine").Instance()
local input               = require("input/Input").Instance()
local Task                = require("system/Task")
local RouteModeController = require("controller/RouteModeController")
require("controller/ControlInterface")

---@enum FlightMode
FlightMode = {
    Route = 1,
    FreeFlight = 2,
    StepWise = 3
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
        ifc = RouteModeController.New(input, commandLine)
        ifc.Setup()
    end

    local function setupFreeFlightMode()
        --[[ Moves in the direction the player looks, as long as a button is held.
            Needed functionality
            - Altitude hold
            - Speed control
            - Landing assist "press G"
        ]]
    end

    local function setupStepwiseMode()
        -- Moves from point A to B, always stopping at B.
    end

    ---Sets new operational mode
    ---@param newMode FlightMode
    function s.SetMode(newMode)
        if mode ~= newMode then
            mode = newMode
            holdPosition()

            if ifc then ifc.TearDown() end

            if mode == FlightMode.Route then
                setupRouteMode()
            elseif mode == FlightMode.FreeFlight then
                setupFreeFlightMode()
            else
                setupStepwiseMode()
            end
        end
    end

    -- Create a Task to handle communication with the screen
    Task.New("ControllScreen", screenTask)

    -- Register for events from the flight system
    -- All the things currently in widgets

    return setmetatable(s, SystemController)
end

return SystemController
