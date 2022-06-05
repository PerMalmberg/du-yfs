-- https://github.com/Sleitnick/AeroGameFramework/blob/master/src/StarterPlayer/StarterPlayerScripts/Aero/Modules/PID.lua

--[[
    Library abstraction. This is assumes the project is being compiled with du-LuaC (https://github.com/wolfe-labs/DU-LuaC/) which provides
    a GetCoreUnit() function via the global 'library'.
]]
local utils = require("cpml/utils")
local clamp = utils.clamp
local pid = {}
pid.__index = pid

local function new(p, i, d, min, max)
    return setmetatable(
            {
                kp = p,
                ki = i,
                kd = d,
                preError = 0,
                integral = 0,
                min = min,
                max = max,
                output = 0
            },
            pid
    )
end

function pid:Feed(deltaT, setPoint, currentValue)
    local err = (setPoint - currentValue)
    local pOut = (self.kp * err)
    self.integral = self.integral + (err * deltaT)
    local iOut = (self.ki * self.integral)
    local deriv = ((err - self.preError) / deltaT)
    local dOut = (self.kd * deriv)
    self.output = clamp((pOut + iOut + dOut), self.min, self.max)
    self.preError = err
    return self.output
end

function pid:Get()
    return self.output
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