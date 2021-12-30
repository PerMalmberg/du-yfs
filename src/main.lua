local FlightCore = require("FlightCore")
local EngineGroup = require("EngineGroup")
local vec3 = require("builtin/vec3")

local fc = FlightCore(unit)
local core = library.getCoreUnit()
fc:ReceiveEvents()
fc:SetAcceleration(EngineGroup("ALL"), -vec3(core.getWorldVertical()), core.g()* 5)