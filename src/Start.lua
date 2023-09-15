local log              = require("debug/Log").Instance()
local ControlCommands  = require("controller/ControlCommands")
local RouteController  = require("flight/route/RouteController")
local BufferedDB       = require("storage/BufferedDB")
local Fuel             = require("info/Fuel")
local FlightFSM        = require("flight/FlightFSM")
local FlightCore       = require("flight/FlightCore")
local ScreenController = require("controller/ScreenController")
local Communcation     = require("controller/Communication")
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
local Access           = require("Access")
local GeoFence         = require("flight/GeoFence")
local Radar            = require("element/Radar")

---Main routine that starts the system
---@param isECU boolean
local function Start(isECU)
    log.SetLevel(LVL.WARNING)

    local routeDbName = "Routes"
    local routeLink   = library.getLinkByName(routeDbName)

    if not routeLink then
        log.Error("Must link a databank named '", routeDbName, "'")
        unit.exit()
        return
    end

    local settingsDbName = "Settings"
    local settingLink = library.getLinkByName(settingsDbName)
    if not settingLink then
        log.Info("No DB named '", settingsDbName, "' linked falling back to route DB.")
        settingLink = routeLink
    end

    if isECU then
        log.Info("Running as ECU")
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
    local radar = Radar.Instance()

    local followRemote = library.getLinkByName("FollowRemote") ---@type any

    if followRemote and (type(followRemote.activate) ~= "function" or type(followRemote.deactivate) ~= "function") then
        followRemote = nil
    end

    if followRemote then
        log.Info("Found FollowRemote switch")
        followRemote.activate()

        unit:onEvent("onStop", function()
            followRemote.deactivate()
        end)
    end

    Task.New("Main", function()
        settingsDb.BeginLoad()
        routeDb.BeginLoad()

        while not settingsDb:IsLoaded() or not routeDb:IsLoaded() do
            coroutine.yield()
        end

        local access = Access.New(settingsDb, commandLine)
        commandLine.SetAccess(access.CanExecute)

        local rc = RouteController.Instance(routeDb)
        local fsm = FlightFSM.New(settings, rc, GeoFence.New(settingsDb, commandLine))
        local fc = FlightCore.New(rc, fsm)
        fsm.SetFlightCore(fc)

        settings.Reload()
        fc.ReceiveEvents()

        local floor = floorDetector.Measure()
        if not floor.Hit or floor.Distance > settings.Get("autoShutdownFloorDistance") then
            log.Info("No floor detected within set limit during startup, holding postition.")
            rc.ActivateHoldRoute()
            fc.StartFlight()
        elseif isECU then
            log.Info("Floor detected, shutting down")
            unit.exit()
        else
            fsm.SetState(Idle.New(fsm))
        end

        if not isECU then
            screen = ScreenController.New(fc, settings)
            wsad = Wsad.New(fsm, fc, settings, access)
        end

        fuel = Fuel.New(settings)
        commands = ControlCommands.New(input, commandLine, fc, settings, screen, access)

        info = InfoCentral.Instance()
        hud = Hud.New()

        commands.RegisterMoveCommands()
        commands.RegisterCommonCommands(isECU)
        if not isECU then
            commands.RegisterRouteCommands()
            radar.Show(settings.Boolean("showRadarOnStart"))
            radar.Sort(settings.Number("defaultRadarMode"))

            settings.RegisterCallback("defaultRadarMode", function(value)
                radar.Sort(value)
            end)
        end

        pub.Publish("ShowInfoWidgets", settings.Boolean("showWidgetsOnStart", false))

        local channel = settings.String("commChannel")
        local comm
        if not isECU and channel ~= "" then
            comm = Communcation.New(channel)
        end
    end).Catch(function(t)
        log.Error(t.Name(), t.Error())
    end)

    Task.New("FloorMonitor", function()
        if floorDetector.Present() then
            log.Info("FloorMonitor started")
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
        log.Info("Auto shutdown disabled")
    end).Catch(function(t)
        log.Error(t.Name(), t.Error())
    end)
end

return Start
