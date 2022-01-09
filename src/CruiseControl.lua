local cc = {}
cc.__index = cc

---Initiates a travel in the given direction at the given speed
---@param direction vec3 The direction to travel towards
---@param speed number The speed in m/s to travel
function cc:Travel(direction, speed)
end

--#region New
local singelton = nil

local new = function(...)
    local instance = {

    }

    setmetatable(instance, cc)

    return instance
end

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
--#endregion
