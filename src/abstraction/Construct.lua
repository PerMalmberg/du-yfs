local library = require("abstraction/Library")()
local vec3 = require("builtin/cpml/vec3")
local Constants = require("Constants")

local coreUnit = {}
coreUnit.__index = coreUnit
local singelton = nil

---Creates a new Core
---@return table A new AxisControl
local function new()
    local core = library.GetCoreUnit()
    local ctrl = library.GetController()

    local instance = {
        orientation = {
            Up = function()
                -- This points in the current up direction of the construct
                return vec3(core.getConstructWorldOrientationUp())
            end,
            Right = function()
                -- This points in the current right direction of the construct
                return vec3(core.getConstructWorldOrientationRight())
            end,
            Forward = function()
                -- This points in the current forward direction of the construct
                return vec3(core.getConstructWorldOrientationForward())
            end,
            AlongGravity = function()
                -- This points towards the center of the planet, i.e. downwards
                return vec3(core.getWorldVertical())
            end,
            localized = {
                Up = function()
                    return vec3(core.getConstructOrientationUp())
                end,
                Right = function()
                    return vec3(core.getConstructOrientationRight())
                end,
                Forward = function()
                    return vec3(core.getConstructOrientationForward())
                end
            }
        },
        velocity = {
            Angular = function()
                return vec3(core.getWorldAngularVelocity())
            end,
            Movement = function()
                return vec3(core.getWorldAbsoluteVelocity())
            end,
            localized = {
                Angular = function()
                    return vec3(core.getAngularVelocity())
                end
            }
        },
        acceleration = {
            Angular = function()
                return vec3(core.getWorldAngularAcceleration())
            end,
            Movement = function()
                return vec3(core.getWorldAcceleration())
            end,
            localized = {
                Angular = function()
                    return vec3(core.getAngularAcceleration())
                end
            }
        },
        position = {
            Current = function()
                return vec3(core.getConstructWorldPos())
            end
        },
        world = {
            AtmoDensity = core.getAtmosphereDensity,
            IsInAtmo = function()
                return core.getAtmosphereDensity() > Constants.atmoToSpaceDensityLimit
            end,
            G = core.g,
            AngularAirFrictionAcceleration = function()
                return vec3(core.getWorldAirFrictionAcceleration())
            end
        },
        player = {
            position = {
                Current = function()
                    return vec3(ctrl.getMasterPlayerWorldPosition())
                end
            }
        }
    }

    setmetatable(instance, coreUnit)
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
