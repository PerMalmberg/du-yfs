-- Universe - utility class to manage the in-game atlas

local universe = {}
universe.__index = universe

require("Asserts")
local diag = require("Diagnostics")()

local Galaxy = require("Galaxy")
local singelton = nil

local function new()
    local instance = {
        core = library.getCoreUnit(),
        galaxies = {} -- Galaxies by id
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
    -- local closest = self.core.getCurrentPlanetId()
    -- return self.gameAtlas[self:CurrentGalaxyId()][closest]
end

function universe:Prepare()
    local ga = require("atlas")
    diag:AssertIsTable(ga, "In-game atlas must be a table")

    for galaxyId, galaxy in pairs(ga) do
        diag:Debug()
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
