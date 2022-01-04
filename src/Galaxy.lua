-- galaxy - utility class to manage the in-game atlas

local Body = require("Body")
local diag = require("Diagnostics")()

local galaxy = {}
galaxy.__index = galaxy

local singelton = nil

local function new()
    local instance = {
        body = {} -- Stellar bodies by id
    }
    setmetatable(instance, galaxy)

    return instance
end

function galaxy:BodyById(id)
    return self.body[id]
end

function galaxy:Prepare(galaxyAtlas)
    diag:AssertIsTable(galaxyAtlas, "galaxyAtlas must be a table")

    for bodyId, bodyData in pairs(galaxyAtlas) do
        self.body[bodyId] = Body(bodyData)
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
                singelton:Prepare(...)
            end
            return singelton
        end
    }
)
