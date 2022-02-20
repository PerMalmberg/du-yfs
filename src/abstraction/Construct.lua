local library = require("abstraction/Library")()
local vec3 = require("cpml/vec3")

local construct = {}
construct.__index = construct
local singelton = nil

local atmoToSpaceDensityLimit = 0 -- At what density level we consider space to begin. Densities higher than this is atmo.

local core = library.GetCoreUnit()
local ctrl = library.GetController()

---Creates a new Core
---@return table A new AxisControl
local function new()
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
                -- This points towards the center of the planet, i.e. downwards. Is zero when in space.
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
        mass = {
            Own = function()
                return core.getConstructMass()
            end,
            Total = function()
                local m = singelton.mass
                return m.Own() + m.MassOfDockedConstructs() + m.MassOfPlayers()
            end,
            MassOfDockedConstructs = function()
                local mass = 0
                for _, id in ipairs(core.getDockedConstructs()) do
                    mass = mass + core.getDockedConstructMass(id)
                end

                return mass
            end,
            MassOfPlayers = function()
                local mass = 0
                for _, id in ipairs(core.getPlayersOnBoard()) do
                    mass = mass + core.getBoardedPlayerMass(id)
                end
                return mass
            end
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
            AtmoDensity = ctrl.getAtmosphereDensity,
            IsInAtmo = function()
                return ctrl.getAtmosphereDensity() > atmoToSpaceDensityLimit
            end,
            IsInSpace = function()
                return not singelton.world.IsInAtmo()
            end,
            G = core.g,
            AngularAirFrictionAcceleration = function()
                return vec3(core.getWorldAirFrictionAcceleration())
            end,
            GAlongGravity = function()
                return vec3(core.getWorldGravity())
            end
        },
        player = {
            position = {
                Current = function()
                    return vec3(ctrl.getMasterPlayerWorldPosition())
                end
            },
            orientation = {
                Up = function()
                    return vec3(ctrl.getMasterPlayerWorldUp())
                end
            },
            camera = {
                position = {
                    Current = function()
                        return vec3(system.getCameraWorldPos())
                    end
                },
                orientation = {
                    Forward = function()
                        return vec3(system.getCameraWorldForward())
                    end,
                    Up = function()
                        return vec3(system.getCameraWorldUp())
                    end,
                    Right = function()
                        return vec3(system.getCameraWorldRight())
                    end,
                    IsFirstPerson = system.isFirstPerson
                }
            }
        }
    }

    setmetatable(instance, construct)
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
