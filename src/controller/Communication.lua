---@module "Settings"

local RxTx = require("device/RxTx")
local Stream = require("Stream")

local rx = library.getLinkByClass("ReceiverUnit")
local tx = library.getLinkByClass("EmitterUnit")

local log = require("debug/Log").Instance()
local pub = require("util/PubSub").Instance()

---@class Communication
---@field OnData fun(table)
---@field OnTimeout fun(isTimedOut:boolean, stream:Stream)
---@field RegisterStream fun(stream:Stream)

local Communication = {}
Communication.__index = Communication

---@param channel string
---@return Communication
function Communication.New(channel)
    local s = {}
    local stream ---@type Stream
    local timedOut = true

    local queue = {} ---@type {topic:string, data:table}

    pub.RegisterTable("SendData", function(_, value)
        if value.topic and value.data then
            queue[#queue + 1] = value
        else
            log.Error("Got data to send without topic or value")
        end
    end)

    ---@param incomingData {topic:string, data:table|string}
    function s.OnData(incomingData)
        local topic = incomingData.topic
        local data = incomingData.data

        if topic and data then
            pub.Publish("RecData-" .. topic, data)
        end
    end

    function s.OnTimeout(isTimedOut, stream)
        if timedOut and not isTimedOut then
            log.Info("Communication established")
        elseif not timedOut and isTimedOut then
            log.Info("Communication lost")
        end
        timedOut = isTimedOut
    end

    function s.RegisterStream(stream)
        -- NOP
    end

    setmetatable(s, Communication)

    if not (rx and tx) then
        log.Error("Emitter or receiver not linked")
        unit.exit()
    end

    stream = Stream.New(RxTx.New(tx, rx, channel, true), s, 1)

    system:onEvent("onUpdate", function()
        if not stream.WaitingToSend() then
            local toSend = table.remove(queue, 1)
            if toSend then
                stream.Write(toSend)
            end
        end
        stream.Tick()
    end)

    log.Info("Communication enabled")

    return s
end

return Communication
