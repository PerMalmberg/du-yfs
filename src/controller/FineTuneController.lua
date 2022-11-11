---@class FineTuneController

local FineTuneController = {}
FineTuneController.__index = FineTuneController

---@param input Input
---@param cmd CommandLine
---@param flightCore FlightCore
---@return ControlInterface
function FineTuneController.New(input, cmd, flightCore)
    local s = {}

    function s.Setup()
        player.freeze(true)
    end

    function s.TearDown()
        player.freeze(false)
        input.Clear()
        cmd.Clear()
    end

    return setmetatable(s, FineTuneController)
end

return FineTuneController
