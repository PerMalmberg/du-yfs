local pub = require("util/PubSub").Instance()
local sharedPanel = require("panel/SharedPanel")()

---@class Controller

local Controller = {}
Controller.__index = Controller

---@param flightCore FlightCore
---@return Controller
function Controller.New(flightCore)
    local s = {}

    -- Create a Task to handle communication with the screen (or screens?)

    -- Setup command line

    -- Register for events from the flight system



    return setmetatable(s, Controller)
end

return Controller
