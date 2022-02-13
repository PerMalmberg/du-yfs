local library = require("abstraction/Library")()
local vec3 = require("builtin/cpml/vec3")

local atan = math.atan
local sqrt = math.sqrt
local max = math.max
local min = math.min
local abs = math.abs
local core = library.GetCoreUnit()
local solve3 = library.GetSolver3()

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
        local localized = coordinate - vec3(core.getConstructWorldPos())
        return vec3(solve3(core.getConstructWorldRight(), core.getConstructWorldForward(), core.getConstructWorldUp(), {localized:unpack()}))
    end,
    SignedRotationAngle = function(normal, vecA, vecB)
        vecA = vecA:project_on_plane(normal)
        vecB = vecB:project_on_plane(normal)
        return atan(vecA:cross(vecB):dot(normal), vecA:dot(vecB))
    end
}

return calc
