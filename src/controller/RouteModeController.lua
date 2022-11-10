---@module "commandline/CommandLine"
---@module "input/Input"

---@class RouteModeController

local RouteModeController = {}
RouteModeController.__index = RouteModeController

---Creates a new RouteModeController
---@param input Input
---@param commandline CommandLine
---@return ControlInterface
function RouteModeController.New(input, commandline)
    local s = {}

    function s.Setup()

    end

    function s.TearDown()
        input.Clear()
        commandline.Clear()
    end

    return setmetatable(s, RouteModeController)
end

return RouteModeController
