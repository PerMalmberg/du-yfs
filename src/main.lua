local RouteController = require("flight/route/Controller")
local BDB = require("du-libs:storage/BufferedDB")
local FC = require("flight/FlightCore")
local Input = require("Input")

local routeDb = BDB("routes")
routeDb:BeginLoad()
local rc = RouteController(routeDb)

local fc = FC(rc)
fc:ReceiveEvents()

Input:New(fc)