--[[
    Library abstraction. This is assumes the project is being compiled with du-LuaC (https://github.com/wolfe-labs/DU-LuaC/) which provides
    a GetCoreUnit() function via the global 'library'.
]]

local libraryProxy = {}
libraryProxy.__index = libraryProxy

local singelton = nil

local function new()
    return setmetatable({}, libraryProxy)
end

function libraryProxy:GetCoreUnit()
    -- Are we running live?
    if library then
        return library.getCoreUnit()
    else
        -- In test, return a mock
        return require("mock/Core")()
    end
end

function libraryProxy:GetController()
    if library then
        return unit -- Return the global unit
    else
        return require("mock/Controller")()
    end
end

function libraryProxy:GetSolver3()
    if library then
        return library.systemResolution3
    end
    return nil
end

function libraryProxy:GetLinkByName(name)
    if library then
        return library.getLinkByName(name)
    end
    return nil
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