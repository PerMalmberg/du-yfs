local Vec3       = require("math/Vec3")
local log        = require("debug/Log").Instance()
local universe   = require("universe/Universe").Instance()
local vehicle    = require("abstraction/Vehicle").New()
local Current    = vehicle.position.Current

---@alias GeoFenceData {centerPos:string, boundary:number, enabled:boolean}

---@class GeoFence
---@field Limited fun(travelDir:Vec3):boolean

local GeoFence   = {}
GeoFence.__index = GeoFence

---@param db BufferedDB
---@param cmdLine CommandLine
---@return GeoFence
function GeoFence.New(db, cmdLine)
    local s = {}

    local center = Vec3.zero

    ---@type GeoFenceData
    local cfg = {
        enabled = false,
        centerPos = "",
        boundary = 0, ---@type number
    }

    local KEY = "geofence"

    local function load()
        local c = db.Get(KEY)
        ---@cast c GeoFenceData
        if c then
            cfg.boundary = c.boundary
            cfg.centerPos = c.centerPos
            cfg.enabled = c.enabled

            if cfg.centerPos ~= nil and cfg.centerPos ~= "" then
                center = universe.ParsePosition(cfg.centerPos).Coordinates()
            end

            cfg.boundary = cfg.boundary or 150
        end
    end

    local function save()
        db.Put(KEY, cfg)
        local c = universe.ParsePosition(cfg.centerPos)
        if c then
            center = c.Coordinates()
        end
    end

    local geo = cmdLine.Accept("geofence",
        ---@param data {commandValue:string, boundary:number}
        function(data)
            if data.boundary <= 0 then
                log.Error("Boundary must be > 0")
                return
            end

            local c = universe.ParsePosition(data.commandValue)
            if c then
                cfg.centerPos = c.AsPosString()
                cfg.boundary = data.boundary
                cfg.enabled = true
                save()

                center = c.Coordinates()
            end
        end).AsString().Must()
    geo.Option("boundary").AsNumber().Must()

    cmdLine.Accept("disable-geofence", function()
        cfg.enabled = false
        save()
    end)

    cmdLine.Accept("print-geofence", function(data)
        log.Info(cfg)
    end)

    ---@param travelDir Vec3
    ---@return boolean #True if limited
    function s.Limited(travelDir)
        if cfg.enabled and cfg.centerPos ~= nil and cfg.centerPos ~= "" then
            local pos = Current()
            local dir, dist = (center - pos):NormalizeLen()

            -- Outside boundary or moving >90 degrees away from center
            return dist > cfg.boundary and dir:Dot(travelDir) < 0
        end

        return false
    end

    function s.Center()
        return center
    end

    load()

    return setmetatable(s, GeoFence)
end

return GeoFence
