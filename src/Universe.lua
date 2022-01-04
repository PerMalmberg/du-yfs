-- Universe - utility class to manage the in-game atlas

local diag = require("Diagnostics")()
local library = require("abstraction/Library")()
local Galaxy = require("Galaxy")

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

--- Gets the information for the closest stellar body
---@return table
function universe:ClosestBody()
    local closest = self.core.getCurrentPlanetId()
    return self.galaxy[self:CurrentGalaxyId()]:BodyById(closest)
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
