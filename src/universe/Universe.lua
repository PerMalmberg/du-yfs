-- Universe - utility class to manage the in-game atlas

local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local Galaxy = require("universe/Galaxy")
local Position = require("universe/Position")
local vec3 = require("builtin/cpml/vec3")
local cos = math.cos
local sin = math.sin

local stringMatch = string.match
local numberPattern = " *([+-]?%d+%.?%d*e?[+-]?%d*)"
local posPattern =
    "::pos{" ..
    numberPattern .. "," .. numberPattern .. "," .. numberPattern .. "," .. numberPattern .. "," .. numberPattern .. "}"

local universe = {}
universe.__index = universe

local singelton = nil

local function new()
    local instance = {
        core = library.getCoreUnit(),
        galaxy = {} -- Galaxies by id
    }
    setmetatable(instance, universe)

    return instance
end

---Gets the current galaxy id
---@return integer The id of the current galaxy
function universe:CurrentGalaxyId()
    return 0 -- Until there are more than one galaxy in the game.
end

---Gets the current galaxy
---@return Galaxy The current galaxy
function universe:CurrentGalaxy()
    return self.galaxy[self:CurrentGalaxyId()]
end

---Parses a position string
---@param pos string The "::pos{...}" string
---@return Position A position in space or on a planet
function universe:ParsePosition(pos)
    local x, y, z, bodyRef
    local galaxyId, bodyId, latitude, longitude, altitude = stringMatch(pos, posPattern)

    if galaxyId ~= nil then
        galaxyId = tonumber(galaxyId)
        bodyId = tonumber(bodyId)

        --[[Positions in space, such as asteroids have no bodyId id. In this case
            latitude, longitude, altitude are x, y, z in meters.

            In either case, the closest stellar body is set as the positions body.
        ]]
        if bodyId == 0 then
            x = tonumber(latitude)
            y = tonumber(longitude)
            z = tonumber(altitude)
            bodyRef = self:ClosestBodyByDistance(galaxyId, vec3(x, y, z))
            return Position(self.galaxy[galaxyId], bodyRef, x, y, z)
        else
            -- https://stackoverflow.com/questions/1185408/converting-from-longitude-latitude-to-cartesian-coordinates
            -- The x-axis goes through long,lat (0,0), so longitude 0 meets the equator
            -- The y-axis goes through (0,90)
            -- and the z-axis goes through the poles.
            -- Positions on a body have lat, long in degrees and altitude in meters
            latitude = math.rad(latitude)
            longitude = math.rad(longitude)
            local body = self.galaxy[galaxyId]:BodyById(bodyId)

            local radius = body.Geography.Radius + altitude
            local cosLat = cos(latitude)
            local position =
                vec3(radius * cosLat * cos(longitude), radius * cosLat * sin(longitude), radius * sin(latitude))
            position = position + body.Geography.Center

            return Position(self.galaxy[galaxyId], body, position.x, position.y, position.z)
        end
    end

    diag:Error("Invalid postion string", pos)

    return nil
end

--- Gets the information for the closest stellar body
---@return table
function universe:ClosestBody()
    local closest = self.core.getCurrentPlanetId()
    return self.galaxy[self:CurrentGalaxyId()]:BodyById(closest)
end

function universe:ClosestBodyByDistance(galaxyId, position)
    return self.galaxy[galaxyId]:GetBodyClosestToPosition(position)
end

function universe:Prepare()
    local ga = require("builtin/atlas")
    diag:AssertIsTable(ga, "In-game atlas must be a table")

    for galaxyId, galaxy in pairs(ga) do
        --diag:Debug("Building galaxy", galaxyId)
        self.galaxy[galaxyId] = Galaxy(galaxyId, ga[galaxyId])
    end
end

return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            if singelton == nil then
                singelton = new()
                singelton:Prepare()
            end
            return singelton
        end
    }
)
