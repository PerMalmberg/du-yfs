local pub, log, Stopwatch = require("util/PubSub").Instance(), require("debug/Log").Instance(),
    require("system/Stopwatch")

---@class GateControl
---@field Instance fun():GateControl
---@field Open fun()
---@field Close fun()
---@field Enabled fun():boolean
---@field Enable fun(on:boolean)

local GateControl         = {}
GateControl.__index       = {}

local instance

function GateControl.Instance()
    if instance then return instance end

    local s = {}
    local wantsOpen = false
    local enabled = true
    local timer = Stopwatch.New()
    local followGate = library.getLinkByName("FollowGate") ---@type any

    if followGate and (type(followGate.activate) ~= "function" or type(followGate.deactivate) ~= "function") then
        followGate = nil
    end

    if followGate then
        log.Info("Found FollowGate switch")
    end

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

            if followGate then
                if wantsOpen then
                    followGate.activate()
                else
                    followGate.deactivate()
                end
            end
        end
    end)

    return instance
end

return GateControl
