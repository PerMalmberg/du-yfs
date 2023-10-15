require("GlobalTypes")
local log = require("debug/Log").Instance()
local Lock = require("element/Lock")
local v = require("version_out")
local linked, isECU = require("variants/CoreLinkCheck")()

---@class Limited
---@field New fun():Limited
---@field AddLimit fun(count:number, size:EngineSize, engineType:EngineType)

local Limited = {}
Limited.__index = Limited

function Limited.New()
    local s = {}
    local lock = Lock.New()

    function s.Start()
        log.Info(v.APP_NAME)
        log.Info(v.APP_VERSION)

        if linked then
            local start = require("Start")
            start(isECU)

            Task.New("Lock", function()
                if lock.ValidateCo() then
                    log.Info("Engine check passed")
                else
                    error("Engine check failed")
                end
            end).Catch(function(t)
                unit.exit()
            end)
        else
            unit.exit()
        end
    end

    ---@param engineType EngineType
    ---@param size EngineSize
    ---@param count integer
    function s.AddLimit(engineType, size, count)
        lock.AddLimit(engineType, size, count)
    end

    return setmetatable(s, Limited)
end

return Limited
