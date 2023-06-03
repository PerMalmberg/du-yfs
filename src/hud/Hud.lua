local Template = require("Template")
local Task = require("system/Task")
local standardHud = library.embedFile("hud.html")
local ecuHud = library.embedFile("ecu.html")
local log = require("debug/Log").Instance()
local pub = require("util/PubSub").Instance()
local MaxSpeed = require("abstraction/Vehicle").New().speed.MaxSpeed
local calc = require("util/Calc")
local Mps2Kph = calc.Mps2Kph
local Round = calc.Round

---@alias HudData {speed:number, maxSpeed:number}

---@class Hud
---@field New fun():Hud

local Hud = {}
Hud.__index = Hud


---@return Hud
function Hud.New()
    local s = {}
    local lastData ---@type FlightData
    local throttleValue = 0
    local unitInfo = system.getItem(unit.getItemId())
    local isECU = unitInfo.displayNameWithSize:lower():match("emergency")
    local selectedHud
    if isECU then
        selectedHud = ecuHud
    else
        selectedHud = standardHud
    end

    system.showScreen(true)

    Task.New("HUD", function()
        local tpl = Template(selectedHud, {}, function(obj, err)
            log.Error("Error compiling template: ", err)
        end)

        while true do
            if lastData then
                local html = tpl({
                    targetSpeed = Round(Mps2Kph(lastData.targetSpeed), 1),
                    maxSpeed = Round(Mps2Kph(MaxSpeed()), 1),
                    throttleValue = throttleValue
                })
                system.setScreen(html)
            end
            coroutine.yield()
        end
    end).Catch(function(t)
        log.Error(t.Name(), " ", t.Error())
    end)


    pub.RegisterTable("FlightData",
        ---@param _ string
        ---@param data FlightData
        function(_, data)
            lastData = data
        end)

    pub.RegisterNumber("ThrottleValue",
        function(_, value)
            throttleValue = value
        end)

    return setmetatable(s, Hud)
end

return Hud
