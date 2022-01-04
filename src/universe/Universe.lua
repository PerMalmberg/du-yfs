-- Universe - utility class to manage the in-game atlas

local library = require("abstraction/Library")()
local diag = require("Diagnostics")()
local Galaxy = require("universe/Galaxy")
local Position = require("universe/Position")
local Body = require("universe/Body")
local vec3 = require("builtin/vec3")

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
---@return integer The id of the galaxy
function universe:CurrentGalaxyId()
    return 0 -- Until there are more than one galaxy in the game.
end

---Parses a position string
---@param pos string
---@return Position A position in space or on a planet
function universe:ParsePosition(pos)
    local x, y, z, bodyRef
    local galaxyId, bodyId, latitude, longitude, altitude = stringMatch(pos, posPattern)

    if galaxyId ~= nil then
        galaxyId = tonumber(galaxyId)
        bodyId = tonumber(bodyId)

        -- Positions in space, such as asteroids have no bodyId id. In this case latitude, longitude, altitude are x, y, z in meters.
        if bodyId == 0 then
            x = tonumber(latitude)
            y = tonumber(longitude)
            z = tonumber(altitude)
            bodyRef = self:ClosestBodyByDistance(galaxyId, vec3(x, y, z))
            return Position(galaxyId, bodyRef, x, y, z)
        else
            -- Positions on a body have lat, long in degrees and altitude in meters
            latitude = math.rad(latitude)
            longitude = math.rad(longitude)
            local body = self.galaxy[galaxyId]:BodyById(bodyId)
            local xProjection = math.cos(latitude)
            local bodyX = xProjection * math.cos(longitude)
            local bodyY = xProjection * math.sin(latitude)
            local bodyZ = math.sin(latitude)
            local position = body.Geography.Center + (body.Geography.Radius + altitude) * vec3(bodyX, bodyY, bodyZ)
            return Position(galaxyId, body, position.x, position.y, position.z)
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
        diag:Debug("Building galaxy", galaxyId)
        self.galaxy[galaxyId] = Galaxy(ga[galaxyId])
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
