---Represents a position in the universe.

local diag = require("Diagnostics")()
local vec3 = require("builtin/vec3")
local stringFormat = string.format

local position = vec3()

local function new(galaxy, bodyRef, x, y, z)
    diag:AssertIsTable(galaxy, "galaxy for a position must be a table")
    diag:AssertIsTable(bodyRef, "bodyRef for a position must be a table")
    diag:AssertIsNumber(x, "X for a position must be a number")
    diag:AssertIsNumber(y, "Y for a position must be a number")
    diag:AssertIsNumber(z, "Z for a position must be a number")

    local instance = {
        Planet = bodyRef,
        Galaxy = galaxy,
        Coords = vec3(x, y, z)
    }

    setmetatable(instance, position)

    return instance
end

function position:__tostring()
    -- The game starts giving space coordinates at an altitude of 70km above
    -- the planets radius on Alioth so we're mimicing that behaviour.
    local altitude = (self.Coords - self.Planet.Geography.Center):len() - self.Planet.Geography.Radius
    if altitude < self.Planet.Geography.Radius + 70000 then
        -- Use a radius that includes the altitude
        local radius = self.Planet.Geography.Radius + altitude
        -- Calculate around origo; planet center is added in Universe:ParsePosition
        -- and we're reversing that calculation.
        local calcPos = self.Coords - self.Planet.Geography.Center
        local lat = math.asin(calcPos.z / radius)
        local lon = math.atan(calcPos.y, calcPos.x)

        return stringFormat("::pos{%d,%d,%.4f,%.4f,%.4f}", self.Galaxy.Id, self.Planet.Id, math.deg(lat), math.deg(lon), altitude)
    else
        return stringFormat("::pos{%d,0,%.4f,%.4f,%.4f}", self.Galaxy.Id, self.Coords.x, self.Coords.y, self.Coords.z)
    end
end

return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            return new(...)
        end
    }
)
