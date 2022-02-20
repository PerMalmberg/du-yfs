---Represents a position in the universe.

local diag = require("Diagnostics")()
local vec3 = require("cpml/vec3")
local stringFormat = string.format

local position = vec3()

local function new(galaxy, bodyRef, x, y, z)
    diag:AssertIsTable(galaxy, "galaxy", "Position:new")
    diag:AssertIsTable(bodyRef, "bodyRef", "Position:new")
    diag:AssertIsNumber(x, "X", "Position:new")
    diag:AssertIsNumber(y, "Y", "Position:new")
    diag:AssertIsNumber(z, "Z", "Position:new")

    local instance = {
        Body = bodyRef,
        Galaxy = galaxy,
        Coords = vec3(x, y, z)
    }

    setmetatable(instance, position)

    return instance
end

function position:__tostring()
    -- The game starts giving space coordinates at an altitude of 70km above
    -- the planets radius on Alioth so we're mimicing that behaviour.
    local altitude = (self.Coords - self.Body.Geography.Center):len() - self.Body.Geography.Radius
    if altitude < self.Body.Geography.Radius + 70000 then
        -- Use a radius that includes the altitude
        local radius = self.Body.Geography.Radius + altitude
        -- Calculate around origo; planet center is added in Universe:ParsePosition
        -- and we're reversing that calculation.
        local calcPos = self.Coords - self.Body.Geography.Center
        local lat = math.asin(calcPos.z / radius)
        local lon = math.atan(calcPos.y, calcPos.x)

        return stringFormat("::pos{%d,%d,%.4f,%.4f,%.4f}", self.Galaxy.Id, self.Body.Id, math.deg(lat), math.deg(lon), altitude)
    else
        return stringFormat("::pos{%d,0,%.4f,%.4f,%.4f}", self.Galaxy.Id, self.Coords.x, self.Coords.y, self.Coords.z)
    end
end

--[[
---Calculates the distance 'as the crow flies' to the other position
---using the haversine formula
---@param other Position The position to calculate the distance to.
function position:DistanceAtHeight(other)
    -- http://www.movable-type.co.uk/scripts/latlong.html
    if self.Body.Id == other.Body.Id then
        
    else
        diag:Error("Different planet ids", self.Body.Id, other.Body.Id)
    end

    return nil
end
]]
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
