local ControlCommands = require("controller/ControlCommands")
local Criteria        = require("input/Criteria")
local Task            = require("system/Task")
local ValueTree       = require("util/ValueTree")
local InfoCentral     = require("info/InfoCentral")
local log             = require("debug/Log")()
local pub             = require("util/PubSub").Instance()
local commandLine     = require("commandline/CommandLine").Instance()
local input           = require("input/Input").Instance()

local Stream     = require("Stream")
local serializer = require("util/Serializer")

---@module "controller/ControlInterface"

---@class SystemController

local SystemController = {}
SystemController.__index = SystemController

---@param flightCore FlightCore
---@param settings Settings
---@return SystemController
function SystemController.New(flightCore, settings)
    local s = {}
    local ifc = ControlCommands.New(input, commandLine, flightCore)

    local info = InfoCentral.Instance()
    local routeController = flightCore.GetRouteController()

    local function screenTask()
        local screen = library.getLinkByClass("ScreenUnit")

        if not screen then return end

        log:Info("Screen found")

        local function dataReceived(data)
            -- Publish data to system

        end

        local function timeOut(isTimedOut)

        end

        local tree = ValueTree.New()
        local stream = Stream.New(screen, dataReceived, 1, timeOut)

        while screen do
            coroutine.yield()
            stream.Tick()

            if not stream.WaitingToSend() then
                -- Get data to send to screen
                local data = tree.Pick()
                -- Send data to screen
                if data then
                    local ser = serializer.Serialize({ flightData = data })
                    if ser then
                        --- @cast ser string
                        stream.Write(ser)
                    end
                end
            end
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
