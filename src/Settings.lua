local log = require("debug/Log")()
local cmd = require("commandline/CommandLine").Instance()
local yfsConstants = require("YFSConstants")
require("util/Table")

---@module "storage/BufferedDB"

---@class Settings
---@field New fun(db:BufferedDB)
---@field RegisterCallback fun(key:string, f:fun(any))
---@field Reload fun()
---@field Get fun(key:string, default?:any):string|number|table|nil
---@field Number fun(key:string, default?:number):number
---@field Boolean fun(key:string, default?:boolean):boolean
---@field String fun(key:string, default?:string):string

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

    local function publishToSubscribers(key, value)
        -- Notify subscribers for the key
        local subs = subscribers[key]
        if subs then
            for _, f in pairs(subs) do
                f(value)
            end
        end
    end

    local containerSettings = {
        containerProficiency = { default = 0 },
        fuelTankOptimization = { default = 0 },
        containerOptimization = { default = 0 },
        atmoFuelTankHandling = { default = 0 },
        spaceFuelTankHandling = { default = 0 },
        rocketFuelTankHandling = { default = 0 },
    }

    local pidValues = yfsConstants.flight.speedPid
    local routeDefaults = yfsConstants.route
    local flightDefaults = yfsConstants.flight
    ---@type {default:string|number|boolean}
    local settings = {
        engineWarmup = { default = 1 },
        speedp = { default = pidValues.p },
        speedi = { default = pidValues.i },
        speedd = { default = pidValues.d },
        speeda = { default = pidValues.a },
        autoShutdownFloorDistance = { default = routeDefaults.autoShutdownFloorDistance },
        yawAlignmentThrustLimiter = { default = routeDefaults.yawAlignmentThrustLimiter },
        routeStartDistanceLimit = { default = routeDefaults.routeStartDistanceLimit },
        showWidgetsOnStart = { default = yfsConstants.widgets.showOnStart },
        throttleStep = { default = yfsConstants.flight.throttleStep },
        manualControlOnStartup = { default = false },
        turnAngle = { default = yfsConstants.flight.defaultTurnAngle },
        minimumPathCheckOffset = { default = flightDefaults.minimumPathCheckOffset },
        showFloor = { default = "-" }
    }

    for k, v in pairs(containerSettings) do
        settings[k] = v
    end

    local set = cmd.Accept("set",
        ---@param data table
        function(data)
            for key, _ in pairs(settings) do
                local val = data[key]
                if val ~= nil then
                    db.Put(key, val)
                    publishToSubscribers(key, val)
                    log:Info("Set", key, " to ", val)
                end
            end
        end)

    for key, v in pairs(settings) do
        local opt = string.format("-%s", key)
        if type(v.default) == "number" then
            set.Option(opt).AsNumber()
        elseif type(v.default) == "string" then
            set.Option(opt).AsString()
        elseif type(v.default) == "boolean" then
            set.Option(opt).AsBoolean()
        end
    end

    cmd.Accept("reset-settings", function(_)
        for key, value in pairs(settings) do
            db.Put(key, value.default)
            log:Info("Reset", key, " to ", value.default)
        end

        s.Reload()
    end)

    cmd.Accept("get",
        ---@param data {commandValue:string}
        function(data)
            local setting = settings[data.commandValue]

            if setting == nil then
                log:Error("Unknown setting:", data.commandValue)
                return
            end


            log:Info(data.commandValue, ": ", s.Get(data.commandValue, setting.default))
        end).AsString().Mandatory()

    cmd.Accept("get-all", function(_)
        for key, v in pairs(settings) do
            log:Info(key, ": ", s.Get(key))
        end
    end)

    cmd.Accept("set-full-container-boosts", function(_)
        for key, _ in pairs(containerSettings) do
            cmd.Exec(string.format("set -%s %d", key, 5))
        end
    end)

    ---@param key string The key to get notified of
    ---@param func fun(any) A function with signature function(value)
    function s.RegisterCallback(key, func)
        if not subscribers[key] then
            subscribers[key] = {}
        end

        table.insert(subscribers[key], func)
    end

    ---@param key string
    ---@param default? string|number|table|boolean|nil
    ---@return string|number|table|boolean|nil
    function s.Get(key, default)
        local setting = settings[key]

        -- If no default is provided, use the one in the definition
        if default == nil then
            return db.Get(key, setting.default)
        end

        return db.Get(key, default)
    end

    ---@param key string
    ---@param default? boolean
    ---@return boolean
    function s.Boolean(key, default)
        local v = s.Get(key, default)
        ---@cast v boolean
        return v
    end

    ---@param key string
    ---@param default? number
    ---@return number
    function s.Number(key, default)
        local v = s.Get(key, default)
        ---@cast v number
        return v
    end

    ---@param key string
    ---@param default? string
    ---@return string
    function s.String(key, default)
        local v = s.Get(key, default)
        ---@cast v string
        return v
    end

    function s.Reload()
        for key, _ in pairs(settings) do
            local stored = s.Get(key)
            publishToSubscribers(key, stored)
        end
    end

    singleton = setmetatable(s, Settings)
    return singleton
end

return Settings
