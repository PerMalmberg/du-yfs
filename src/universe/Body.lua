-- Body - stellar bodies

local diag = require("Diagnostics")()
local vec3 = require("builtin/cpml/vec3")
local ENGLISH = 1

local body = {}
body.__index = body

local function new()
    local instance = {}
    setmetatable(instance, body)

    return instance
end

function body:Prepare(galaxy, data)
    diag:AssertIsTable(galaxy, "galayx data must be a table")
    diag:AssertIsTable(data, "Body data must be a table")

    self.Galaxy = galaxy
    self.Id = data.id
    self.Name = data.name[ENGLISH]
    self.Type = data.type[ENGLISH]

    self.Physics = {
        Gravity = data.gravity
    }
    self.Geography = {
        Center = vec3(data.center),
        Radius = data.radius
    }
    self.Atmosphere = {
        Present = data.hasAtmosphere,
        Thickness = data.atmosphereThickness,
        Radius = data.atmosphereRadius
    }
    self.Surface = {
        MaxAltitude = data.surfaceMaxAltitude,
        MinAltitude = data.surfaceMinAltitude
    }
    self.Pvp = {
        LocatedInSafeZone = data.isInSafeZone
    }

    --diag:Debug("Stellar body", self.Name)
end

return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            local b = new()
            b:Prepare(...)
            return b
        end
    }
)
