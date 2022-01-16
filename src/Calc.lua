local atan = math.atan

local calc = {
    Round = function(number, decimalPlaces)
        local mult = 10 ^ (decimalPlaces or 0)
        return math.floor(number * mult + 0.5) / mult
    end,
    RotationFrom = function(normal, a, b)
        a = a:project_on_plane(normal)
        b = b:project_on_plane(normal)
        return atan(a:cross(b):dot(normal), a:dot(b))
    end
}

return calc
