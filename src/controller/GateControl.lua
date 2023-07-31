local pub           = require("util/PubSub").Instance()
local Stopwatch     = require("system/Stopwatch")
local log           = require("debug/Log").Instance()

local GateControl   = {}
GateControl.__index = {}

local instance

function GateControl.Instance()
    if instance then return instance end

    local s = {}
    local wantsOpen = false
    local timer = Stopwatch.New()

    ---@param topic string
    ---@param data {state:string}
    local function onData(topic, data)
        if data.state == wantsOpen then
            timer.Stop()
            log.Info("Gates reported in desired state")
        end
    end

    local function activate(open)
        wantsOpen = open
        timer.Restart()
    end

    function s.Open()
        activate(true)
    end

    function s.Close()
        activate(false)
    end

    function s.AreInDesiredState()
        -- When timer no longer is running, gates are in the expected state. (Assuming Open or Closed has been called.)
        return not timer.IsRunning()
    end

    instance = setmetatable(s, GateControl)
    pub.RegisterTable("RecData-GateControl", onData)

    system:onEvent("onUpdate", function()
        if timer.IsRunning() and timer.Elapsed() > 0.5 then
            timer.Restart()
            pub.Publish("SendData",
                { topic = "GateControl", data = { desiredState = wantsOpen } })
        end
    end)

    return instance
end

return GateControl
