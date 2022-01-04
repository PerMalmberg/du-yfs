local FlightCore = require("FlightCore")
local EngineGroup = require("EngineGroup")
local vec3 = require("builtin/vec3")
local Universe = require("Universe")
local library = require("abstraction/Library")()

local core = library.getCoreUnit()
local fc = FlightCore()

fc:ReceiveEvents()
local stab = fc:GetStabilizer():StablilizeUpward()
local stab = fc:GetStabilizer():TurnTowards(vec3(core.getConstructWorldOrientationForward()))
fc:SetAcceleration(EngineGroup("ALL"), -vec3(core.getWorldVertical()), core.g()*1.005)

local u = Universe()