local library = require("abstraction/Library")()
local Vec3 = require("cpml/vec3")

local core = library:GetCoreUnit()
local solve3 = library:GetSolver3()

local atan = math.atan
local max = math.max
local min = math.min
local abs = math.abs

local calc = {
    ---Returns the absolute difference between a and b
    ---@param a any Value a to compare
    ---@param b any Value b to compare
    ---@return any Absolute difference between the two numbers.
    AbsDiff = function(a, b)
        a, b = abs(a), abs(b)
        return max(a, b) - min(a, b)
    end,
    Round = function(number, decimalPlaces)
        local mult = 10 ^ (decimalPlaces or 0)
        return math.floor(number * mult + 0.5) / mult
    end,
    Sign = function(v)
        if v > 0 then
            return 1
        elseif v < 0 then
            return -1
        else
            return 0
        end
    end,
    Scale = function(value, inMin, inMax, outMin, outMax)
        return (outMax - outMin) / (inMax - inMin) * (value - inMin) + outMin
    end,
    WorldToLocal = function(coordinate)
        local localized = coordinate - Vec3(core.getConstructWorldPos())
        return Vec3(solve3(core.getConstructWorldRight(), core.getConstructWorldForward(), core.getConstructWorldUp(), { localized:unpack() }))
    end,
    SignedRotationAngle = function(normal, vecA, vecB)
        vecA = vecA:project_on_plane(normal)
        vecB = vecB:project_on_plane(normal)
        return atan(vecA:cross(vecB):dot(normal), vecA:dot(vecB))
    end,
    StraightForward = function(up, right)
        return up:cross(right)
    end,
    Mps2Kph = function(mps)
        return mps * 3.6
    end,
    Kph2Mps = function(kph)
        return kph / 3.6
    end,
    NearestPointOnLine = function(lineStart, lineDirection, pointAwayFromLine)
        --local v = pointAwayFromLine - lineStart
        --return v:project_on(lineDirection:normalize())

        -- https://forum.unity.com/threads/how-do-i-find-the-closest-point-on-a-line.340058/
        local lineDir = lineDirection:normalize()
        local v = pointAwayFromLine - lineStart
        local d = v:dot(lineDir)
        return lineStart + lineDir * d
    end,
    IsNaN = function(value)
        return value ~= value
    end,
    AreAlmostEqual = function(a, b, margin)
        return abs(a - b) < margin
    end
}

return calc