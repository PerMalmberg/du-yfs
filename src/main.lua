local r = require("CommonRequire")
local fc = require("flight/FlightCore")()
local Input = require("Input")

local brakes = r.brakes
local brakeLight = r.library:GetLinkByName("brakelight")

fc:ReceiveEvents()

local function Update(system)
    if brakeLight ~= nil then
        if brakes:IsEngaged() then
            brakeLight.activate()
        else
            brakeLight.deactivate()
        end
    end
end
system:onEvent("onUpdate", Update)

local input = Input:New(fc)