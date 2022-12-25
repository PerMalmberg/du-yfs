local ControlCommands = require("controller/ControlCommands")
local Task            = require("system/Task")
local ValueTree       = require("util/ValueTree")
local InfoCentral     = require("info/InfoCentral")
local log             = require("debug/Log")()
local commandLine     = require("commandline/CommandLine").Instance()
local input           = require("input/Input").Instance()
local layout          = library.embedFile("../screen/layout_min.json")
local Stream          = require("Stream")
local json            = require("dkjson")

---@module "controller/ControlInterface"

---@class SystemController

local SystemController = {}
SystemController.__index = SystemController

---@param flightCore FlightCore
---@param settings Settings
---@return SystemController
function SystemController.New(flightCore, settings)
    local s = {}
    local commands = ControlCommands.New(input, commandLine, flightCore)

    local info = InfoCentral.Instance()
    local routeController = flightCore.GetRouteController()

    local function screenTask()
        local screen = library.getLinkByClass("ScreenUnit")

        if not screen then return end

        log:Info("Screen found")

        ---@param t table
        ---@return string
        local function serialize(t)
            local r = json.encode(t)
            ---@cast r string
            return r
        end

        local function dataReceived(data)
            -- Publish data to system
            system.print(data)
        end

        local layoutSent = false

        ---@param isTimedOut boolean
        ---@param stream Stream
        local function onTimeout(isTimedOut, stream)
            if isTimedOut then
                layoutSent = false
            elseif not layoutSent then
                stream.Write(serialize({ screen_layout = json.decode(layout) }))
                stream.Write(serialize({ activate_page = "routeSelection" }))
                layoutSent = true
            end
        end

        local tree = ValueTree.New()
        local stream = Stream.New(screen, dataReceived, 1, onTimeout)

        while screen do
            coroutine.yield()
            stream.Tick()

            if not stream.WaitingToSend() then
                -- Get data to send to screen
                local data = tree.Pick()
                -- Send data to screen
                if data then
                    local ser = json.encode({ flightData = data })
                    if ser then
                        --- @cast ser string
                        stream.Write(ser)
                    end
                else
                    stream.Write('{"keepalive": ""}')
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
