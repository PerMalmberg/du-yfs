local Font       = require("native/Font")
local Color      = require("native/Color")
local Screen     = require("native/Screen")
local Stream     = require("Stream")
local Vec2       = require("native/Vec2")
local Binder     = require("Binder")
local Behaviour  = require("Behaviour")
local log        = require("native/RenderScript").Log
local serializer = require("util/Serializer")

local screen = Screen.New()
local layer = screen.Layer(1)
local behavior = Behaviour.New()
local font = Font.Get(FontName.Play, 30)

local middle = screen.Bounds() / 2
local speed = layer.Text("Speed: 0", middle, font)
speed.Props.Fill = Color.New(1, 1, 1)

local binder = Binder.New()
local path = binder.Path("flightData/flight", 1)
path.Number(speed, "Text", "absspeed", "Speed: %0.1f km/h")


local onDataReceived = function(data)
    local d = serializer.Deserialize(data)
    if d then
        ---@cast d table
        binder.MergeData(d)
    end
end

local timeoutCallback = function(isTimedOut)

end

local stream = Stream.New(_ENV, onDataReceived, 1, timeoutCallback)

stream.Tick()

behavior.TriggerEvents(screen)
binder.Render()
screen.Render(true)
