local log        = require("debug/Log").Instance()
local cmd        = require("commandline/CommandLine").Instance()
local constants  = require("YFSConstants")

---@module "storage/BufferedDB"

---@class Settings
---@field Create fun(db:BufferedDB):Settings
---@field Instance fun():Settings
---@field Callback fun(key:string, f:fun(any))
---@field Reload fun()
---@field Get fun(key:string, default?:any):string|number|table|nil
---@field Number fun(key:string, default?:number):number
---@field Boolean fun(key:string, default?:boolean):boolean
---@field String fun(key:string, default?:string):string

local singleton
local Settings   = {}
Settings.__index = Settings

---Creates a new Setting
---@param db BufferedDB
---@return Settings
function Settings.Create(db)
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

    local f = constants.flight
    local speedPid = f.speedPid
    local lightPid = f.axis.light
    local heavyPid = f.axis.heavy
    local routeDefaults = constants.route
    ---@type {default:string|number|boolean}
    local settings = {
        engineWarmup = { default = 1 },
        speedp = { default = speedPid.p },
        speedi = { default = speedPid.i },
        speedd = { default = speedPid.d },
        speeda = { default = speedPid.a },
        lightp = { default = lightPid.p },
        lighti = { default = lightPid.i },
        lightd = { default = lightPid.d },
        lighta = { default = lightPid.a },
        heavyp = { default = heavyPid.p },
        heavyi = { default = heavyPid.i },
        heavyd = { default = heavyPid.d },
        heavya = { default = heavyPid.a },
        autoShutdownFloorDistance = { default = routeDefaults.autoShutdownFloorDistance },
        yawAlignmentThrustLimiter = { default = routeDefaults.yawAlignmentThrustLimiter },
        routeStartDistanceLimit = { default = routeDefaults.routeStartDistanceLimit },
        showWidgetsOnStart = { default = constants.widgets.showOnStart },
        throttleStep = { default = constants.flight.throttleStep },
        manualControlOnStartup = { default = false },
        turnAngle = { default = constants.flight.defaultTurnAngle },
        minimumPathCheckOffset = { default = f.minimumPathCheckOffset },
        showFloor = { default = "-" },
        pathAlignmentAngleLimit = { default = f.pathAlignmentAngleLimit },
        pathAlignmentDistanceLimit = { default = f.pathAlignmentDistanceLimit },
        pathAlignmentDistanceLimitFromSurface = { default = 0 },
        setWaypointAlongRoute = { default = false },
        commChannel = { default = "" },
        shutdownDelayForGate = { default = 2 },
        openGateWaitDelay = { default = 3 },
        openGateMaxDistance = { default = 10 },
        dockingMode = { default = 1 }, -- 1 = Manual, 2 = Automatic, 3 = Only own constructs,
        globalMaxSpeed = { default = 0 },
        showRadarOnStart = { default = false },
        defaultRadarMode = { default = 1 },
        allowForwardToggle = { default = false },
        autoBrakeAngle = { default = 45 },
        parkMaxSpeed = { default = 50 }
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
                    log.Info("Set '", key, "' to '", val, "'")
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
            log.Info("Reset '", key, "' to '", value.default, "'")
        end

        s.Reload()
    end)

    cmd.Accept("strict-mode", function()
        local opts = { "allowForwardToggle", "yawAlignmentThrustLimiter", "manualControlOnStartup",
            "minimumPathCheckOffset" }

        for _, k in ipairs(opts) do
            db.Put(k, settings[k].default)
        end

        s.Reload()
        log.Info("Settings adjusted for strict mode")
    end)

    cmd.Accept("free-mode", function()
        db.Put("yawAlignmentThrustLimiter", 360)
        db.Put("manualControlOnStartup", true)
        db.Put("minimumPathCheckOffset", 5000)
        db.Put("allowForwardToggle", true)
        db.Put("turnAngle", 3)
        s.Reload()
        log.Info("Settings adjusted for free mode")
    end)

    cmd.Accept("get",
        ---@param data {commandValue:string}
        function(data)
            local setting = settings[data.commandValue]

            if setting == nil then
                log.Error("Unknown setting: ", data.commandValue)
                return
            end


            log.Info(data.commandValue, ": ", s.Get(data.commandValue, setting.default))
        end).AsString().Must()

    cmd.Accept("get-all", function(_)
        local keys = {} ---@type string[]
        for key, _ in pairs(settings) do
            keys[#keys + 1] = key
        end

        table.sort(keys)

        for _, key in pairs(keys) do
            log.Info(key, ": ", s.Get(key))
        end
    end)

    cmd.Accept("set-full-container-boosts", function(_)
        for key, _ in pairs(containerSettings) do
            cmd.Exec(string.format("set -%s %d", key, 5))
        end
    end)

    ---@param key string The key to get notified of
    ---@param func fun(any) A function with signature function(value)
    function s.Callback(key, func)
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

---@return Settings
function Settings.Instance()
    if not singleton then
        error("Settings not yet created")
    end

    return singleton
end

return Settings
