---Represents a position in the universe.

local diag = require("Diagnostics")()
local vec3 = require("builtin/vec3")

local position = vec3() -- Inherit from vec3
position.__index = position

local function new(galaxyId, bodyRef, x, y, z)
    diag:AssertIsNumber(galaxyId, "galaxyId for a position must be a number")
    diag:AssertIsTable(bodyRef, "bodyRef for a position must be a table")
    diag:AssertIsNumber(x, "X for a position must be a number")
    diag:AssertIsNumber(y, "Y for a position must be a number")
    diag:AssertIsNumber(z, "Z for a position must be a number")


    local instance = {
        Planet = bodyRef,
        Galaxy = galaxyId
    }

    setmetatable(instance, position)

    instance.x = x
    instance.y = y
    instance.z = z

    return instance
end

function position:__tostring()
    return "foo"
end

return setmetatable(
    {
        new = new
    },
    {
        __call = function(_, ...)
            return new(...)
        end
    }
)
