local Font      = require("Font")
local Color     = require("Color")
local Screen    = require("Screen")
local Stream    = require("Stream")
local Vec2      = require("Vec2")
local Binder    = require("Binder")
local Behaviour = require("Behaviour")
local json      = require("dkjson")
local topics    = require("Topics")
local log       = require("RenderScript").Log

local function fd(topic)
    return string.format("flightData/%s", topic)
end

local screen = Screen.New()
local layer = screen.Layer(1)
local behavior = Behaviour.New()
local font = Font.Get(FontName.Play, 30)

layer.Text(string.format("%0.2f%%", screen.Stats()), Vec2.New(), font)

local middle = screen.Bounds() / 2
local speed = layer.Text("Speed: 0", middle, font)
speed.Props.Fill = Color.New(1, 1, 1)

local binder = Binder.New()
local path = binder.Path("flightData/flight")
path.Number(speed, "Text", "absspeed", "Speed: %0.1f km/h")


local onDataReceived = function(data)
    local j = json.decode(data)
    if j then
        ---@cast j table
        binder.MergeData(j)
    else
        error(j)
    end
end

local timeoutCallback = function(isTimedOut)

end

local stream = Stream.New(_ENV, onDataReceived, 1, timeoutCallback)

stream.Tick()

behavior.TriggerEvents(screen)
binder.Render()
screen.Render()
