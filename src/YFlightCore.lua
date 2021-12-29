local vec3 = require("builtin/vec3")
local Core = require("src.abstraction/Core")
local Controller = require("src/abstractions/Controller")

YFC = {
    controller = nil,
    core = nil
}

YFC.RollAxle = vec3(0, 1, 0)
YFC.PitchAxle = vec3(1, 0, 0)
YFC.YawAxle = vec3(0, 0, 1)
YFC.Forward = vec3(0, 1, 0)
YFC.Right = vec3(1, 0, 0)
YFC.Up = vec3(0, 0, 1)

local function new()
    return setmetatable(
        {
            core = Core(),
            ctrl = Controller()
        }
    )
end

function YFC:new()
    return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                return new()
            end
        },
        YFC
    )
end

function YFC:MoveInDirection(direction --[[vec3]], acceleration --[[Acceleration]])
    local x, y, z = direction:unpack()
    self.ctrl.SetEngineCommand("ALL", {x, y, z}, acceleration:Value())
end

-- The module
return setmetatable(
	{
		new = new
	}, {
		__call = function(_, ...) return new() end
	}
)