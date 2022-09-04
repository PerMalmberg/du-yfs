local r = require("CommonRequire")
local log = r.log
local RouteController = require("flight/route/Controller")
local BDB = require("storage/BufferedDB")
local FlightFSM = require("flight/FlightFSM")
local FC = require("flight/FlightCore")
local Input = require("Input")
local Settings = require("Settings")

local runner = require("system/CoRunner")(0.5)
local settingsDb = BDB("routes")
local routeDb = BDB("routes")
local settings = Settings:New(settingsDb)

local NAME = "Yoarii's Flight System"
local VERSION = "0.0.0"

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
            settings:Reload()

            local fc = FC(RouteController(routeDb), fsm)
            fc:ReceiveEvents()
            Input:New(fc)

            runner:Terminate()
        end)