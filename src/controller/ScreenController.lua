local Stopwatch      = require("system/Stopwatch")
local Task           = require("system/Task")
local ValueTree      = require("util/ValueTree")
local InfoCentral    = require("info/InfoCentral")
local log            = require("debug/Log")()
local commandLine    = require("commandline/CommandLine").Instance()
local pub            = require("util/PubSub").Instance()
local layout         = library.embedFile("../screen/layout_min.json")
local Stream         = require("Stream")
local json           = require("dkjson")
local calc           = require("util/Calc")
local distanceFormat = require("util/DistanceFormat")
local massFormat     = require("util/MassFormat")
local TotalMass      = require("abstraction/Vehicle").New().mass.Total

---@param t table
---@return string
local function serialize(t)
    coroutine.yield()
    local r = json.encode(t)
    coroutine.yield()
    ---@cast r string
    return r
end

---@param s string
---@return table|nil
local function deserialize(s)
    coroutine.yield()
    local d = json.decode(s)
    coroutine.yield()
    ---@cast d table
    return d
end

local function dataReceived(data)
    -- Publish data to system
    data = deserialize(data)
    if data == nil then return end
    local command = data["mouse_click"]
    if command ~= nil then
        commandLine.Exec(command)
    end
end

---@class ScreenController

local ScreenController = {}
ScreenController.__index = ScreenController

---@param flightCore FlightCore
---@param settings Settings
---@return ScreenController
function ScreenController.New(flightCore, settings)
    local s = {}
    local layoutSent = false

    local info = InfoCentral.Instance()
    local rc = flightCore.GetRouteController()
    local dataToScreen = ValueTree.New()
    local routePage = 1
    local routesPerPage = 5

    ---@param stream Stream
    local function sendRoutes(stream)
        local t = { route = {} }
        for i, r in ipairs(rc.GetRoutePage(routePage, routesPerPage)) do
            t.route[tostring(i)] = { visible = true, name = r }
        end

        -- Ensure to hide the rest if routes have been removed.
        for i = TableLen(t.route) + 1, routesPerPage, 1 do
            t.route[tostring(i)] = { visible = false, name = "" }
        end

        stream.Write(serialize(t))
    end

    ---@param isTimedOut boolean
    ---@param stream Stream
    local function onTimeout(isTimedOut, stream)
        if isTimedOut then
            layoutSent = false
        elseif not layoutSent then
            stream.Write(serialize({ screen_layout = deserialize(layout) }))
            stream.Write(serialize({ activate_page = "routeSelection" }))
            sendRoutes(stream)
            layoutSent = true
        end
    end

    local function screenTask()
        local screen = library.getLinkByClass("ScreenUnit")

        if not screen then return end
        log:Info("Screen found")
        screen.activate()

        local routeTimer = Stopwatch.New()
        routeTimer.Start()

        pub.RegisterTable("FlightData",
            ---@param _ string
            ---@param data FlightData
            function(_, data)
                dataToScreen.Set("flightData/absSpeed", calc.Mps2Kph(data.absSpeed))
                local formatted = distanceFormat(data.waypointDist)
                dataToScreen.Set("nextWp/distance", formatted.value)
                dataToScreen.Set("nextWp/distanceUnit", formatted.unit)

                formatted = massFormat(TotalMass())
                dataToScreen.Set("mass/total", formatted.value)
                dataToScreen.Set("mass/totalUnit", formatted.unit)
            end)

        pub.RegisterTable("RouteData",
            ---@param _ string
            ---@param data {remaining:RouteRemainingInfo, activeRouteName:string|nil}
            function(_, data)
                local formatted = distanceFormat(data.remaining.TotalDistance)
                dataToScreen.Set("finalWp/distance", formatted.value)
                dataToScreen.Set("finalWp/distanceUnit", formatted.unit)
                dataToScreen.Set("route/current/name", data.activeRouteName)
            end)

        pub.RegisterTable("AdjustmentData",
            ---@param _ string
            ---@param data AdjustmentData
            function(_, data)
                dataToScreen.Set("deviation/distance", data.distance)
            end)

        pub.RegisterTable("FloorMonitor",
            ---@param _ string
            ---@param value TelemeterResult
            function(_, value)
                local floor = string.format("Hit: %s, distance: %0.2f, limit: %0.2f",
                    tostring(value.Hit), value.Distance,
                    settings.Number("autoShutdownFloorDistance"))
                dataToScreen.Set("floor", floor)
            end)

        pub.RegisterTable("FuelData",
            ---@param _ string
            ---@param value {path:string, tank:FuelTankInfo}[]
            function(_, value)
                for i, fuelInfo in ipairs(value) do
                    dataToScreen.Set(fuelInfo.path, fuelInfo.tank)
                end
            end)

        local stream = Stream.New(screen, dataReceived, 1, onTimeout)

        while screen do
            coroutine.yield()
            stream.Tick()

            if not stream.WaitingToSend() then
                if not routeTimer.IsRunning() or routeTimer.Elapsed() > 5 then
                    sendRoutes(stream)
                    routeTimer.Restart()
                end

                -- Get data to send to screen
                local data = dataToScreen.Pick()
                -- Send data to screen
                if data then
                    local ser = json.encode(data)
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
    Task.New("ScreenController", screenTask)
        .Then(function(...)
            log:Info("No screen connected")
        end).Catch(function(t)
        log:Error(t.Name(), t.Error())
    end)

    return setmetatable(s, ScreenController)
end

return ScreenController
