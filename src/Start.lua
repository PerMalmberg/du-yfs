local log              = require("debug/Log")()
local RouteController  = require("flight/route/RouteController")
local BufferedDB       = require("storage/BufferedDB")
local FlightFSM        = require("flight/FlightFSM")
local FlightCore       = require("flight/FlightCore")
local SystemController = require("controller/SystemController")
local Settings         = require("Settings")
local Hud              = require("hud/Hud")
local Task             = require("system/Task")
local Wsad             = require("controller/Wsad")
local floorDetector    = require("controller/FloorDetector").Instance()
local commandLine      = require("commandline/CommandLine").Instance()

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

    local settingsDb = BufferedDB.New(settingLink)
    local routeDb = BufferedDB.New(routeLink)
    local settings = Settings.New(settingsDb)
    local hud ---@type Hud
    local wsad ---@type Wsad

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

        local cont = SystemController.New(fc, settings)
        settings.Reload()
        fc.ReceiveEvents()

        local floor = floorDetector.Measure()
        if not floor.Hit or floor.Distance > settings.Get("autoShutdownFloorDistance") then
            log:Info("No floor detected with set limit during startup, holding postition.")
            rc.ActivateHoldRoute()
            fc.StartFlight()
        else
            fsm.SetState(Idle.New(fsm))
        end

        hud = Hud.New()
        wsad = Wsad.New(fc, commandLine, settings)
    end).Then(function()
        log:Info("Ready.")
    end).Catch(function(t)
        log:Error(t.Name(), t:Error())
    end)
end

return Start
