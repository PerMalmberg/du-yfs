--[[
    Core mock.
]]
local core = {}
core.__index = core

local singelton = nil

CoreVars = {
    worldPos = {-8.00, -8.00, -126303.00}, -- Alioth center
    currentPlanetId = 2, -- Alioth
    constructWorldOrientationForward = {0, 1, 0}
}

local function new()
    return setmetatable({}, core)
end

function core.getConstructWorldOrientationForward()
    return CoreVars.constructWorldOrientationForward
end

---Gets the center of the contruct in world coordinates
---@return vector {x, y, z}
function core.getConstructWorldPos()
    return CoreVars.wordPos
end

---Sets the world positon
---@param position vector {x, y, z}
function core.setWorldPos(position)
    CoreVars.wordPos = position
end

function core.getCurrentPlanetId()
    return CoreVars.currentPlanetId
end

function core.setCurrentPlanetId(id)
    CoreVars.currentPlanetId = id
end

function core.getTime()
    return os.time(os.date("!*t"))
end

-- The module
return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            if singelton == nil then
                singelton = new()
            end
            return singelton
        end
    }
)
