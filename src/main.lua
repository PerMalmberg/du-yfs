local r = require("CommonRequire")
local log = r.log
local RouteController = require("flight/route/Controller")
local BDB = require("du-libs:storage/BufferedDB")
local FlightFSM = require("flight/FlightFSM")
local FC = require("flight/FlightCore")
local Input = require("Input")
local Settings = require("Settings")

local runner = require("du-libs:system/CoRunner")(0.5)
local settingsDb = BDB("routes")
local routeDb = BDB("routes")
local settings = Settings:New(settingsDb)

local NAME = "Yoarii's Flight System"
local VERSION = "0.0.0"

local function loadWarmUptime(fsm, brakes)
    local ew = settings.def.engineWarmup
    local warmupTime = settingsDb:Get(ew.key, ew.default)
    log:Info("Warmup time:", warmupTime)
    -- Warmup time is to T50, so double it for full engine effect
    brakes:SetEngineWarmupTime(warmupTime * 2)
    fsm:SetEngineWarmupTime(warmupTime * 2)
end

runner:Execute(
        function()
            log:Info(NAME)
            log:Info("v", VERSION)

            settingsDb:BeginLoad()
            routeDb:BeginLoad()

            while not settingsDb:IsLoaded() or not routeDb:IsLoaded() do
                coroutine.yield()
            end

            local fsm = FlightFSM(settings)
            loadWarmUptime(fsm, r.brakes)

            local fc = FC(RouteController(routeDb), fsm)
            fc:ReceiveEvents()
            Input:New(fc)

            runner:Terminate()
        end)