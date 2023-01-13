local Telemeter = require("element/Telemeter")
local pub       = require("util/PubSub").Instance()
local log       = require("debug/Log")()
local Vec3      = require("math/Vec3")

---@class FloorDetector
---@field Instance fun():FloorDetector
---@field Measure fun():TelemeterResult
---@field Present fun():boolean

local FloorDetector = {}
FloorDetector.__index = FloorDetector

local instance
local floorDetectorName = "FloorDetector"

---@return FloorDetector
function FloorDetector.Instance()
    if instance then return instance end

    instance = {}

    local teleLink = library.getLinkByName(floorDetectorName)
    local tele ---@type Telemeter|nil

    if teleLink then
        tele = Telemeter.New(teleLink)
        if not tele.IsTelemeter() then
            tele = nil
        end
    else
        log:Error("No telementer by name '", floorDetectorName "' found")
    end

    function instance.Present()
        return tele ~= nil
    end

    ---@return TelemeterResult
    function instance.Measure()
        if tele then
            return tele.Measure()
        else
            return { Hit = false, Distance = 0, Point = Vec3.zero }
        end
    end

    return setmetatable(instance, FloorDetector)
end

return FloorDetector
