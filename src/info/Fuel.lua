require("GlobalTypes")
local s                = require("Singletons")
local log              = s.log
local pub              = s.pub

local Container        = require("element/Container")
local ContainerTalents = require("element/ContainerTalents")
local Task             = require("system/Task")
local Vec2             = require("native/Vec2")
local _                = require("util/Table")

---@alias FuelTankInfo {name:string, factorBar:Vec2, percent:number, visible:boolean, type:string}

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

    local talents = ContainerTalents.New(
        settings.Number("containerProficiency", 0),
        settings.Number("fuelTankOptimization", 0),
        settings.Number("containerOptimization", 0),
        settings.Number("atmoFuelTankHandling", 0),
        settings.Number("spaceFuelTankHandling", 0),
        settings.Number("rocketFuelTankHandling", 0))

    local s = {}

    Task.New("FuelMonitor", function()
        local sw = Stopwatch.New()
        sw.Start()

        local fuelTanks = {
            atmo = Container.GetAllCo(ContainerType.Atmospheric),
            space = Container.GetAllCo(ContainerType.Space),
            rocket = Container.GetAllCo(ContainerType.Rocket)
        }

        while true do
            if sw.IsRunning() and sw.Elapsed() < 2 then
                coroutine.yield()
            else
                local byType = {} ---@type table<string,FuelTankInfo[]>

                for fuelType, tanks in pairs(fuelTanks) do
                    for _, tank in ipairs(tanks) do
                        local factor = tank.FuelFillFactor(talents)
                        local curr = {
                            name = tank.Name(),
                            factorBar = Vec2.New(1, factor),
                            percent = factor * 100,
                            visible = true,
                            type = fuelType
                        }

                        local bt = byType[fuelType] or {}
                        bt[#bt + 1] = curr
                        byType[fuelType] = bt
                    end

                    -- Sort tanks for HUD in alphabetical order
                    if byType[fuelType] then
                        table.sort(byType[fuelType], function(a, b)
                            return a.name < b.name
                        end)
                    end
                end

                pub.Publish("FuelByType", DeepCopy(byType))

                sw.Restart()
            end
        end
    end).Then(function(...)
        log.Info("No fuel tanks detected")
    end).Catch(function(t)
        log.Error(t.Name(), t.Error())
    end)

    settings.Callback("containerProficiency", function(value)
        talents.ContainerProficiency = value
    end)

    settings.Callback("fuelTankOptimization", function(value)
        talents.FuelTankOptimization = value
    end)

    settings.Callback("containerOptimization", function(value)
        talents.ContainerOptimization = value
    end)

    settings.Callback("atmoFuelTankHandling", function(value)
        talents.AtmoFuelTankHandling = value
    end)

    settings.Callback("spaceFuelTankHandling", function(value)
        talents.SpaceFuelTankHandling = value
    end)

    settings.Callback("rocketFuelTankHandling", function(value)
        talents.RocketFuelTankHandling = value
    end)

    instance = setmetatable(s, Fuel)
    return instance
end

return Fuel
