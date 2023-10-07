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
    local outstanding = {} ---@type table<string, table|string>

    local function getOutstanding()
        for k, v in pairs(outstanding) do
            return k, v
        end

        return nil, nil
    end

    pub.RegisterTable("SendData", function(_, value)
        if value.topic and value.data then
            outstanding[value.topic] = value
        else
            log.Error("Got data to send without topic or value")
        end
    end)

    ---@param incomingData {topic:string, data:table|string}
    function s.OnData(incomingData)
        local topic = incomingData.topic
        local data = incomingData.data

        if not (topic and data) then
            log.Error("Received data without topic or value")
            return
        end

        outstanding[topic] = nil

        pub.Publish("RecData-" .. topic, data)
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
    else
        stream = Stream.New(RxTx.New(tx, rx, channel, true), s, 1)

        system:onEvent("onUpdate", function()
            -- Stop sending if we're all done
            local topic, data = getOutstanding()
            if topic and data then
                if not stream.WaitingToSend() then
                    stream.Write(data)
                end

                stream.Tick()
            end
        end)
        log.Info("Communication enabled")
    end

    return s
end

return Communication
