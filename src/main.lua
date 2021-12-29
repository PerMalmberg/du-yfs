local FlightCore = require("FlightCore")
local EngineGroup = require("EngineGroup")

local fc = FlightCore(unit)
fc:ReceiveEvents()
fc:SetAcceleration( EngineGroup("ALL"), FlightCore.Up, 1.05)