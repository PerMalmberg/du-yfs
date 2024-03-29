require("GlobalTypes")
local s = require("Singletons")

local pub, input, commandLine, log, radar, floorDetector = s.pub, s.input, s.commandLine, s.log, s.radar,
    s.floorDetector
local ControlCommands, RouteController, BufferedDB, Fuel, FlightFSM, FlightCore, ScreenController, Communcation, Settings, Hud, InfoCentral, Wsad, Access, GeoFence =
    require("controller/ControlCommands"),
    require("flight/route/RouteController"), require("storage/BufferedDB"), require("info/Fuel"),
    require("flight/FlightFSM"), require("flight/FlightCore"), require("controller/ScreenController"),
    require("controller/Communication"), require("Settings"), require("hud/Hud"), require("info/InfoCentral"),
    require("controller/Wsad"), require("Access"), require("flight/GeoFence")

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
    local settings = Settings.Create(settingsDb)
    local hud ---@type Hud
    local wsad ---@type Wsad
    local commands ---@type ControlCommands
    local screen ---@type ScreenController
    local fuel ---@type Fuel
    local info ---@type InfoCentral

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

        while not settingsDb.IsLoaded() or not routeDb.IsLoaded() do
            coroutine.yield()
        end

        local access = Access.New(settingsDb, commandLine)
        commandLine.SetAccess(access.CanExecute)

        local rc = RouteController.Instance(routeDb)
        local fsm = FlightFSM.New(settings, rc, GeoFence.New(settingsDb, commandLine))
        local fc = FlightCore.New(rc, fsm)
        fsm.SetFlightCore(fc)

        if not isECU then
            screen = ScreenController.New(fc, settings)
            wsad = Wsad.New(fsm, fc, settings, access)
        end

        commands = ControlCommands.New(input, commandLine, fc, settings, screen, access, routeDb)

        settings.Reload()
        -- After this point settings are loaded so any registered callback will not be called.
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

        fuel = Fuel.New(settings)

        info = InfoCentral.Instance()
        hud = Hud.New()

        commands.RegisterMoveCommands()
        commands.RegisterCommonCommands(isECU)
        if not isECU then
            commands.RegisterRouteCommands()
            radar.Show(settings.Boolean("showRadarOnStart"))
            radar.Sort(settings.Number("defaultRadarMode"))

            settings.Callback("defaultRadarMode", function(value)
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
