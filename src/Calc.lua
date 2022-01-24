local library = require("abstraction/Library")()
local vec3 = require("builtin/cpml/vec3")

local atan = math.atan
local sqrt = math.sqrt
local core = library.GetCoreUnit()
local solve3 = library.GetSolver3()

local calc = {
    Round = function(number, decimalPlaces)
        local mult = 10 ^ (decimalPlaces or 0)
        return math.floor(number * mult + 0.5) / mult
    end,
    RotationFrom = function(normal, a, b)
        a = a:project_on_plane(normal)
        b = b:project_on_plane(normal)
        return atan(a:cross(b):dot(normal), a:dot(b))
    end,
    WorldToLocal = function(coordinate)
        local localized = coordinate - vec3(core.getConstructWorldPos())
        return vec3(
            solve3(
                core.getConstructWorldRight(),
                core.getConstructWorldForward(),
                core.getConstructWorldUp(),
                {localized:unpack()}
            )
        )
    end
}

return calc
