local pub = require("util/PubSub").Instance()
local sharedPanel = require("panel/SharedPanel")()

---@enum FlightMode
FlightMode = {
    Auto = 1,
    Manual = 2,
    CommandLine = 3
}

---@class Controller

local Controller = {}
Controller.__index = Controller

---@param flightCore FlightCore
---@return Controller
function Controller.New(flightCore)
    local s = {}
    local mode = Mode.Auto

    local routeController = flightCore.GetRouteController()

    -- Create a Task to handle communication with the screen (or screens?)

    -- Setup command line

    -- Register for events from the flight system

    local function holdPosition()
        local r = routeController.ActivateTempRoute()
        r.AddCurrentPos()
        flightCore.StartFlight()
    end

    ---Sets new operational mode
    ---@param newMode FlightMode
    function s.SetMode(newMode)
        if mode ~= newMode then
            mode = newMode
            holdPosition()
        end
    end

    return setmetatable(s, Controller)
end

return Controller
