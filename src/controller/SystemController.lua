local Container        = require("element/Container")
local ContainerTalents = require("element/ContainerTalents")
local ControlCommands  = require("controller/ControlCommands")
local Stopwatch        = require("system/Stopwatch")
local Task             = require("system/Task")
local ValueTree        = require("util/ValueTree")
local InfoCentral      = require("info/InfoCentral")
local log              = require("debug/Log")()
local commandLine      = require("commandline/CommandLine").Instance()
local pub              = require("util/PubSub").Instance()
local input            = require("input/Input").Instance()
local Vec2             = require("native/Vec2")
local layout           = library.embedFile("../screen/layout_min.json")
local Stream           = require("Stream")
local json             = require("dkjson")
local calc             = require("util/Calc")

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

---@class SystemController

local SystemController = {}
SystemController.__index = SystemController

---@param flightCore FlightCore
---@param settings Settings
---@return SystemController
function SystemController.New(flightCore, settings)
    local s = {}
    local layoutSent = false
    local commands = ControlCommands.New(input, commandLine, flightCore)
    local info = InfoCentral.Instance()
    local rc = flightCore.GetRouteController()
    local dataToScreen = ValueTree.New()
    local talents = ContainerTalents.New(0, 0, 0, 0, 0, 0)

    ---@param stream Stream
    local function sendRoutes(stream)
        local t = { routes = {} } ---@type string[]
        for i, r in ipairs(rc.GetRouteNames()) do
            t.routes[tostring(i)] = r
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

        pub.RegisterTable("FlightData",
            ---@param topic string
            ---@param data FlightData
            function(topic, data)
                dataToScreen.Set("flightData/absSpeed", calc.Mps2Kph(data.absSpeed))
                dataToScreen.Set("flightData/wpDist", calc.Mps2Kph(data.waypointDist))
            end)

        local stream = Stream.New(screen, dataReceived, 1, onTimeout)

        while screen do
            coroutine.yield()
            stream.Tick()

            if not stream.WaitingToSend() then
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
    Task.New("ControllScreen", screenTask)
        .Then(function(...)
            log:Info("No screen connected")
        end).Catch(function(t)
            log:Error(t.Name(), t.Error())
        end)

    settings.RegisterCallback("containerProficiency", function(value)
        talents.ContainerProficiency = value
        log:Info(talents)
    end)

    settings.RegisterCallback("fuelTankOptimization", function(value)
        talents.FuelTankOptimization = value
        log:Info(talents)
    end)

    settings.RegisterCallback("containerOptimization", function(value)
        talents.ContainerOptimization = value
        log:Info(talents)
    end)


    settings.RegisterCallback("atmoFuelTankHandling", function(value)
        talents.AtmoFuelTankHandling = value
        log:Info(talents)
    end)


    settings.RegisterCallback("spaceFuelTankHandling", function(value)
        talents.SpaceFuelTankHandling = value
        log:Info(talents)
    end)


    settings.RegisterCallback("rocketFuelTankHandling", function(value)
        talents.RocketFuelTankHandling = value
        log:Info(talents)
    end)


    Task.New("FuelMonitor", function()
        local sw = Stopwatch.New()
        sw.Start()

        local tanks = {
            atmo = Container.GetAllCo(ContainerType.Atmospheric),
            space = Container.GetAllCo(ContainerType.Space),
            rocket = Container.GetAllCo(ContainerType.Rocket)
        }

        while true do
            if sw.Elapsed() < 2 then
                coroutine.yield()
            else
                for fuelType, containers in pairs(tanks) do
                    local fillFactors = {} ---@type {name:string, factor:number}[]
                    for _, tank in ipairs(containers) do
                        local factor = tank.FuelFillFactor(talents)
                        table.insert(fillFactors,
                            { name = tank.Name(),
                                factorBar = Vec2.New(1, factor),
                                factor = factor })
                        coroutine.yield()
                    end

                    -- Sort tanks in acending fuel levels
                    table.sort(fillFactors,
                        function(a, b) return a.factor < b.factor end)

                    for i, tankInfo in ipairs(fillFactors) do
                        dataToScreen.Set(string.format("fuel/%s/%d", fuelType, i), tankInfo)
                    end

                    coroutine.yield()
                end

                sw.Restart()
            end
        end
    end).Then(function(...)
        log:Info("No fuel tanks detected")
    end).Catch(function(t)
        log:Error(t.Name(), t.Error())
    end)

    return setmetatable(s, SystemController)
end

return SystemController
