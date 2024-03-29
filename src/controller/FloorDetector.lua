local Telemeter, log, Vec3 = require("element/Telemeter"), require("debug/Log").Instance(), require("math/Vec3")

---@class FloorDetector
---@field Instance fun():FloorDetector
---@field Measure fun():TelemeterResult
---@field Present fun():boolean
---@field MaxDist fun():number
---@field IsWithinShutdownDistance fun():boolean
---@field IsParkingEnabled fun():boolean
---@field ReturningHome fun()
---@field IsReturningHome fun():boolean

local FloorDetector        = {}
FloorDetector.__index      = FloorDetector

local inst
local floorDetectorName    = "FloorDetector"

---@return FloorDetector
function FloorDetector.Instance()
    if inst then return inst end

    inst = {}
    local enabled = false

    local teleLink = library.getLinkByName(floorDetectorName)
    local tele ---@type Telemeter|nil

    if teleLink then
        tele = Telemeter.New(teleLink)
        if not tele.IsTelemeter() then
            tele = nil
        end
    else
        log.Error("No telementer by name '", floorDetectorName, "' found")
    end

    function inst.Present()
        return tele ~= nil
    end

    ---@return TelemeterResult
    function inst.Measure()
        if tele then
            return tele.Measure()
        else
            return { Hit = false, Distance = 0, Point = Vec3.zero }
        end
    end

    ---@return number #Max distance or 0
    function inst.MaxDist()
        return tele and tele.MaxDistance() or 0
    end

    return setmetatable(inst, FloorDetector)
end

return FloorDetector
