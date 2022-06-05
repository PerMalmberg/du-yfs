local calc = require("util/Calc")

local numberShape = {}
numberShape.__index = numberShape

function numberShape:Draw()
    local constructLocal = calc.WorldToLocal(self.worldPos)
    if self.index == -1 then
        self.index = self.core.spawnNumberSticker(self.number, constructLocal.x, constructLocal.y, constructLocal.z, "front")
    else
        self.core.moveSticker(self.index, constructLocal.x, constructLocal.y, constructLocal.z)
    end
end

function numberShape:Remove()
    if self.index ~= -1 then
        system:clearEvent("update", self.updateHandler)
        self.core.deleteSticker(self.index)
        self.index = -1
    end
end

local function new(core, number, worldPos)
    local instance = {
        core = core,
        number = number,
        worldPos = worldPos,
        index = -1,
        updateHandler = -1
    }

    setmetatable(instance, numberShape)
    instance.updateHandler = system:onEvent("update", instance.Draw, instance)
    return instance
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