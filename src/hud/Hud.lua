local Template    = require("Template")
local Task        = require("system/Task")
local calc        = require("util/Calc")
local hudTemplate = library.embedFile("hud.html")
local log         = require("debug/Log").Instance()
local pub         = require("util/PubSub").Instance()
local input       = require("input/Input").Instance()

---@alias HudData {speed:number, maxSpeed:number}

---@class Hud
---@field New fun():Hud

local Hud         = {}
Hud.__index       = Hud


---@return Hud
function Hud.New()
    local s = {}
    local flightData = {} ---@type FlightData
    local fuelByType = {} ---@type table<string,FuelTankInfo[]>
    local unitInfo = system.getItem(unit.getItemId())
    local isECU = unitInfo.displayNameWithSize:lower():match("emergency")

    system.showScreen(true)

    Task.New("HUD", function()
        local tpl = Template(hudTemplate, { log = log, tostring = tostring, round = calc.Round }, function(obj, err)
            log.Error("Error compiling template: ", err)
        end)

        while true do
            local html = tpl({
                throttleValue = input.Throttle() * 100,
                fuelByType = fuelByType,
                isECU = isECU
            })
            system.setScreen(html)

            coroutine.yield()
        end
    end).Catch(function(t)
        log.Error(t.Name(), " ", t.Error())
    end)


    pub.RegisterTable("FlightData",
        ---@param _ string
        ---@param data FlightData
        function(_, data)
            flightData = data
        end)

    pub.RegisterTable("FuelByType",
        ---@param _ string
        ---@param data table<string,FuelTankInfo[]>
        function(_, data)
            fuelByType = data
        end)

    return setmetatable(s, Hud)
end

return Hud
