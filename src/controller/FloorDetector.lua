local Telemeter         = require("element/Telemeter")
local log               = require("debug/Log").Instance()
local Vec3              = require("math/Vec3")

---@class FloorDetector
---@field Instance fun():FloorDetector
---@field Measure fun():TelemeterResult
---@field Present fun():boolean
---@field MaxDist fun():number
---@field EnableParking fun(on:boolean)
---@field IsWithinShutdownDistance fun():boolean
---@field IsParkingEnabled fun():boolean

local FloorDetector     = {}
FloorDetector.__index   = FloorDetector

local inst
local floorDetectorName = "FloorDetector"

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

    ---@param v boolean
    function inst.EnableParking(v)
        enabled = v
    end

    function inst.IsParkingEnabled()
        return enabled
    end

    return setmetatable(inst, FloorDetector)
end

return FloorDetector
