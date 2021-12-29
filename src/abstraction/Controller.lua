Controller = {}

local function new()
    return setmetatable(
        {
            ctrl = unit
        }
    )
end

function Controller:new()
    return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                return new()
            end
        }
    )
end

function Controller:SetEngineCommand(tags, direction)
    --
end

-- the module
return setmetatable(
	{
		new = new
	}, {
		__call = function(_, ...) return new(...) end
	}
)