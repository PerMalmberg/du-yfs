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
    WorldToLocal = function(coordinate)
        local localized = coordinate - vec3(core.getConstructWorldPos())
        return vec3(solve3(core.getConstructWorldRight(), core.getConstructWorldForward(), core.getConstructWorldUp(), {localized:unpack()}))
    end,
    ---Returns the alignment offset (-1...0...1) between the construct reference and the target on the plane given by the up and right vectors.
    ---@param referencePosition vec3 The position to base calculations from, i.e. the postion the construct is at.
    ---@param target vec3 The target from which to determine the offset
    ---@param forward vec3 The vector for which we want to know the offset. Also makes up the plane together with 'right'.
    ---@param right vec3 The vector that, with 'forward', makes up the plane on which to determine the offset.
    ---@return number The offset from the direction of the target on the plane.
    --- The range is -1 ... 0 .. 1
    --- 0 means it is perfectly aligned.
    --- > 0 if past target, clockwise.
    --- < 0 if before target, clockwise.
    --- In other words. If 12 a'clock is forward. And we point to 11, we'd get a negative value. If pointing at 1, we'd get a postive value.
    AlignmentOffset = function(referencePosition, target, forward, right)
        -- Create the vector pointing to the target
        local toTarget = target - referencePosition
        toTarget:normalize_inplace()

        -- Create a plane, based on the reference and right vectors.
        -- Negate right to get a normal pointing up (right hand rule for cross product)
        local planeNormal = forward:cross(-right):normalize_inplace()
        -- Project the target vector onto the plane
        local projection = toTarget:project_on_plane(planeNormal)

        -- Determine how far off we are from the forward vector
        local diff = projection:dot(forward)

        -- Determine the direction compared to the target
        local opposite = planeNormal:cross(right):dot(forward) < 0
        local rightOfForward
        -- https://math.stackexchange.com/questions/2584451/how-to-get-the-direction-of-the-angle-from-a-dot-product-of-two-vectors
        if opposite then
            -- Other half-circle than target
            rightOfForward = planeNormal:cross(toTarget):dot(-forward) <= 0
        else
            -- Same half-circle as target
            rightOfForward = planeNormal:cross(toTarget):dot(forward) <= 0
        end

        -- Adjust diff such that 0 means fully aligned and we turn the shortest way towards target.
        if rightOfForward then
            diff = 1 - diff
        else
            diff = diff - 1
        end

        return diff / 2 -- Scale down from 0-2 to to 0-1
    end
}

return calc
