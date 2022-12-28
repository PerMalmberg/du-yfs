local log = require("debug/Log")()
local cmd = require("commandline/CommandLine").Instance()
require("util/Table")

---@module "storage/BufferedDB"

---@class Settings
---@field New fun(db:BufferedDB)
---@field RegisterCallback fun(key:string, f:fun(any))
---@field Reload fun()
---@field RegisterCommands fun()

local singleton
local Settings = {}
Settings.__index = Settings

---Creates a new Setting
---@param db BufferedDB
---@return Settings
function Settings.New(db)
    if singleton then
        return singleton
    end

    local s = {}

    local subscribers = {} ---@type table<string,fun(any)[]>

    s.def = {
        engineWarmup = { key = "engineWarmup", default = 2 },
        speedP = { key = "speedp", default = 0.01 },
        speedI = { key = "speedi", default = 0.005 },
        speedD = { key = "speedd", default = 0.01 },
        speeda = { key = "speeda", default = 0.99 },
        containerProficiency = { key = "containerProficiency", default = 0 },
        fuelTankOptimization = { key = "fuelTankOptimization", default = 0 },
        containerOptimization = { key = "containerOptimization", default = 0 },
        atmoFuelTankHandling = { key = "atmoFuelTankHandling", default = 0 },
        spaceFuelTankHandling = { key = "spaceFuelTankHandling", default = 0 },
        rocketFuelTankHandling = { key = "rocketFuelTankHandling", default = 0 }
    }

    function s.ensureSingle(data)
        -- Ensure only one option is given, ignore commandValue
        local len = TableLen(data)
        if len ~= 2 then
            -- commandValue and one setting
            log:Error("Please specify a single setting, got ", len)
            return false
        end

        return true
    end

    function s.getPair(data)
        for key, value in pairs(data) do
            if key ~= "commandValue" then
                return key, value
            end
        end

        return nil, nil
    end

    function s.publishToSubscribers(key, value)
        -- Notify subscribers for the key
        local subs = subscribers[key]
        if subs then
            for _, f in pairs(subs) do
                f(value)
            end
        end
    end

    ---@param key string The key to get notified of
    ---@param func fun(any) A function with signature function(value)
    function s.RegisterCallback(key, func)
        if not subscribers[key] then
            subscribers[key] = {}
        end

        table.insert(subscribers[key], func)
    end

    function s.Get(key, default)
        return db.Get(key, default)
    end

    function s.Reload()
        for _, setting in pairs(s.def) do
            local stored = s.Get(setting.key, setting.default)
            singleton.publishToSubscribers(setting.key, stored)
        end
    end

    function s.RegisterCommands()
        local setFunc = function(data)
            if not s.ensureSingle(data) then
                return
            end

            local key, value = singleton.getPair(data)
            if key ~= nil then
                s.publishToSubscribers(key, value)
                db.Put(key, value)
            end
        end

        local getFunc = function(data)
            if not singleton.ensureSingle(data) then
                return
            end

            local key, value = singleton.getPair(data)
            if key ~= nil then
                log:Info(key, ": ", db.Get(key, value))
            end
        end

        local set = cmd.Accept("set", setFunc).AsEmpty()

        for _, setting in pairs(singleton.def) do
            -- Don't set defaults on these - prevents detecting which setting is to be set as they all have values then.
            set.Option("-" .. setting.key).AsNumber()
        end
    end

    singleton = setmetatable(s, Settings)
    return singleton

end

return Settings
