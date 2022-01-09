local diag = require("Diagnostics")()
local library = require("abstraction/Library")()
local vec3 = require("builtin/cpml/vec3")
local json = require("builtin/dkjson")

local c = {}
c.__index = c

local MinUpdateInterVal = 5 -- seconds
local decodeJson = json.decode
local getTime = system.getTime

---Calculates the brake distance
---@return number The distance in meter to come to a full stop
function c:BrakeDistance()
    --local airFriction = vec3(self.core.getWorldAirFrictionAcceleration())
end

function c:IsTimeToUpdate()
    local now = getTime()
    local isTime = now - self.lastUpdate >= MinUpdateInterVal
    if isTime then
        self.lastUpdate = now
    end

    return isTime
end

function c:ReceiveEvents()
    self.updateEventId = system:onEvent("update", self.Update, self)
end

function c:Update()
    if not self:IsTimeToUpdate() then
        return
    end

    self:UpdateConstructParameters()
end

function c:UpdateConstructParameters()
    local data = decodeJson(self.ctrl.getData())
    if data.maxBrake ~= nil then
        local m = tonumber(data.maxBrake)
        if self.construct.maxBrake < m then
            self.construct.maxBrake = m
        end
    end
end

--#region New
local singelton = nil

local new = function(...)
    local instance = {
        updateEventId = nil,
        core = library.GetCoreUnit(),
        ctrl = library.GetController(),
        lastUpdate = 0,
        construct = {
            maxBrake = 0
        }
    }

    setmetatable(instance, c)

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
                singelton:ReceiveEvents()
            end
            return singelton
        end
    }
)
--#endregion
