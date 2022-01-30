local vec3 = require("builtin/cpml/vec3")

local constants = {
    flushTick = 1/60.0,
    atmoToSpaceDensityLimit = 0, -- At what density level we consider space to begin. Densities higher than this is atmo.
    universe = {
        up = vec3(0, 1, 0),
        forward = vec3(1, 0, 0),
        right = vec3(0, 0, 1)
    }
}

return constants
