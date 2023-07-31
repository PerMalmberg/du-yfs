local pub           = require("util/PubSub").Instance()
local Stopwatch     = require("system/Stopwatch")
local log           = require("debug/Log").Instance()

---@class GateControl
---@field Instance fun():GateControl
---@field Open fun()
---@field Close fun()
---@field Enabled fun():boolean
---@field Enable fun(on:boolean)

local GateControl   = {}
GateControl.__index = {}

local instance

function GateControl.Instance()
    if instance then return instance end

    local s = {}
    local wantsOpen = false
    local enabled = true
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

    function s.Enable(on)
        enabled = on
    end

    function s.Enabled()
        return enabled
    end

    function s.AreInDesiredState()
        -- When timer no longer is running, gates are in the expected state. (Assuming Open or Closed has been called.)
        return not enabled or not timer.IsRunning()
    end

    instance = setmetatable(s, GateControl)
    pub.RegisterTable("RecData-GateControl", onData)

    system:onEvent("onUpdate", function()
        if enabled and timer.IsRunning() and timer.Elapsed() > 0.5 then
            timer.Restart()
            pub.Publish("SendData",
                { topic = "GateControl", data = { desiredState = wantsOpen } })
        end
    end)

    return instance
end

return GateControl
