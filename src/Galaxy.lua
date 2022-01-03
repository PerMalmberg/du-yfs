-- galaxy - utility class to manage the in-game atlas

local Body = require("Body")
require("Asserts")

local galaxy = {}
galaxy.__index = galaxy

local singelton = nil

local function new()
    local instance = {
        bodies = {} -- Stellar bodies by id
    }
    setmetatable(instance, galaxy)

    return instance
end

--- Gets the information for the closest stellar body
---@return Body The clostest body
function galaxy:ClosestBody()
    -- local closest = self.core.getCurrentPlanetId()
    -- return self.gameAtlas[self:CurrentGalaxyId()][closest]
end

function galaxy:Prepare(galaxyAtlas)
    assert(IsTable(galaxyAtlas), "galaxyAtlas must be a table")
end

return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            if singelton == nil then
                singelton = new()
                singelton:Prepare(...)
            end
            return singelton
        end
    }
)
