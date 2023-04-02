local log              = require("debug/Log")()
local ControlCommands  = require("controller/ControlCommands")
local RouteController  = require("flight/route/RouteController")
local BufferedDB       = require("storage/BufferedDB")
local Fuel             = require("info/Fuel")
local FlightFSM        = require("flight/FlightFSM")
local FlightCore       = require("flight/FlightCore")
local ScreenController = require("controller/ScreenController")
local Settings         = require("Settings")
local Stopwatch        = require("system/Stopwatch")
local Hud              = require("hud/Hud")
local InfoCentral      = require("info/InfoCentral")
local Task             = require("system/Task")
local Wsad             = require("controller/Wsad")
local floorDetector    = require("controller/FloorDetector").Instance()
local commandLine      = require("commandline/CommandLine").Instance()
local pub              = require("util/PubSub").Instance()
local input            = require("input/Input").Instance()

local function Start()
    log:SetLevel(log.LogLevel.WARNING)

    local routeDbName = "Routes"
    local routeLink   = library.getLinkByName(routeDbName)

    if not routeLink then
        log:Error("Must link a databank named '", routeDbName, "'")
        unit.exit()
        return
    end

    local settingsDbName = "Settings"
    local settingLink = library.getLinkByName(settingsDbName)
    if not settingLink then
        log:Info("No DB named '", settingsDbName, "' linked falling back to route DB.")
        settingLink = routeLink
    end

    local unitInfo = system.getItem(unit.getItemId())
    local isECU = unitInfo.displayNameWithSize:lower():match("emergency")
    if isECU then
        log:Info("Running as ECU")
    end

    local settingsDb = BufferedDB.New(settingLink)
    local routeDb = BufferedDB.New(routeLink)
    local settings = Settings.New(settingsDb)
    local hud ---@type Hud
    local wsad ---@type Wsad
    local commands ---@type ControlCommands
    local screen ---@type ScreenController
    local fuel ---@type Fuel
    local info ---@type InfoCentral

    Task.New("Main", function()
        settingsDb.BeginLoad()
        routeDb.BeginLoad()

        while not settingsDb:IsLoaded() or not routeDb:IsLoaded() do
            coroutine.yield()
        end

        local rc = RouteController.Instance(routeDb)
        local fsm = FlightFSM.New(settings, rc)
        local fc = FlightCore.New(rc, fsm)
        fsm.SetFlightCore(fc)

        settings.Reload()
        fc.ReceiveEvents()

        local floor = floorDetector.Measure()
        if not floor.Hit or floor.Distance > settings.Get("autoShutdownFloorDistance") then
            log:Info("No floor detected with set limit during startup, holding postition.")
            rc.ActivateHoldRoute()
            fc.StartFlight()
        elseif isECU then
            log:Info("Floor detected, shutting down")
            unit.exit()
        else
            fsm.SetState(Idle.New(fsm))
        end

        commands = ControlCommands.New(input, commandLine, fc, settings)

        if not isECU then
            screen = ScreenController.New(fc, settings)
            wsad = Wsad.New(fc, commandLine, settings)
            fuel = Fuel.New(settings)
            commands.RegisterRouteCommands()
        end

        info = InfoCentral.Instance()
        hud = Hud.New()
        commands.RegisterMoveCommands()
        commands.RegisterCommonCommands()

        pub.Publish("ShowInfoWidgets", settings.Boolean("showWidgetsOnStart", false))
    end).Then(function()
        log:Info("Ready.")
    end).Catch(function(t)
        log:Error(t.Name(), t:Error())
    end)

    Task.New("FloorMonitor", function()
        if floorDetector.Present() then
            log:Info("FloorMonitor started")
            local sw = Stopwatch.New()
            sw.Start()

            while true do
                coroutine.yield()
                if sw.Elapsed() > 0.3 then
                    sw.Restart()
                    pub.Publish("FloorMonitor", floorDetector.Measure())
                end
            end
        end
    end).Then(function(...)
        log:Info("Auto shutdown disabled")
    end).Catch(function(t)
        log:Error(t.Name(), t.Error())
    end)
end

return Start
