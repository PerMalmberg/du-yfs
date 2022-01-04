-- galaxy - utility class to manage the in-game atlas

local diag = require("Diagnostics")()
local Body = require("universe/Body")

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

---Gets the body closes to the given position
---@param position vec3|Position
---@return Body
function galaxy:GetBodyClosestToPosition(position)
    diag:AssertIsVec3(position, "position must be a vec3 (or Position)")
    local closest = nil
    local smallestDistance = nil

    for _, body in pairs(self.body) do
        local dist = (body.Geography.Center - position):len()
        if smallestDistance == nil or dist < smallestDistance then
            smallestDistance = dist
            closest = body
        end
    end

    return closest
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
