local Container        = require("element/Container")
local ContainerTalents = require("element/ContainerTalents")
local Stopwatch        = require("system/Stopwatch")
local Task             = require("system/Task")
local Vec2             = require("native/Vec2")
local log              = require("debug/Log").Instance()
local pub              = require("util/PubSub").Instance()

---@alias FuelTankInfo {name:string, factorBar:Vec2, percent:number, visible:boolean}

---@class Fuel
---@field Instance fun():Fuel

local Fuel             = {}
Fuel.__index           = Fuel
local instance

---@param settings Settings
---@return Fuel
function Fuel.New(settings)
    if instance then
        return instance
    end

    local talents = ContainerTalents.New(0, 0, 0, 0, 0, 0)

    local s = {}

    Task.New("FuelMonitor", function()
        local sw = Stopwatch.New()
        sw.Start()

        local tanks = {
            atmo = Container.GetAllCo(ContainerType.Atmospheric),
            space = Container.GetAllCo(ContainerType.Space),
            rocket = Container.GetAllCo(ContainerType.Rocket)
        }

        while true do
            if sw.IsRunning() and sw.Elapsed() < 2 then
                coroutine.yield()
            else
                for fuelType, containers in pairs(tanks) do
                    local fillFactors = {} ---@type FuelTankInfo[]
                    for _, tank in ipairs(containers) do
                        local factor = tank.FuelFillFactor(talents)
                        table.insert(fillFactors,
                            {
                                name = tank.Name(),
                                factorBar = Vec2.New(1, factor),
                                percent = factor * 100,
                                visible = true
                            })
                        coroutine.yield()
                    end

                    -- Sort tanks in acending fuel levels
                    table.sort(fillFactors,
                        function(a, b) return a.percent < b.percent end)

                    local fuelData = {}

                    for i, tankInfo in ipairs(fillFactors) do
                        fuelData[#fuelData + 1] = { path = string.format("fuel/%s/%d", fuelType, i), tank = tankInfo }
                    end

                    pub.Publish("FuelData", fuelData)

                    coroutine.yield()
                end

                sw.Restart()
            end
        end
    end).Then(function(...)
        log.Info("No fuel tanks detected")
    end).Catch(function(t)
        log.Error(t.Name(), t.Error())
    end)

    settings.RegisterCallback("containerProficiency", function(value)
        talents.ContainerProficiency = value
    end)

    settings.RegisterCallback("fuelTankOptimization", function(value)
        talents.FuelTankOptimization = value
    end)

    settings.RegisterCallback("containerOptimization", function(value)
        talents.ContainerOptimization = value
    end)

    settings.RegisterCallback("atmoFuelTankHandling", function(value)
        talents.AtmoFuelTankHandling = value
    end)

    settings.RegisterCallback("spaceFuelTankHandling", function(value)
        talents.SpaceFuelTankHandling = value
    end)

    settings.RegisterCallback("rocketFuelTankHandling", function(value)
        talents.RocketFuelTankHandling = value
    end)

    instance = setmetatable(s, Fuel)
    return instance
end

return Fuel
