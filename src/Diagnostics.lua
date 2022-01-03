-- Diagnostic functions

require("Enum")

system =
    system or
    {
        print = function(s)
            io.write(s)
        end
    }

DiagLevel =
    Enum {
    "OFF",
    "ERROR",
    "WARNING",
    "INFO",
    "DEBUG"
}

local diag = {}
diag.__index = diag
local singelton = nil

local function new()
    local instance = {
        level = DiagLevel.DEBUG
    }

    setmetatable(instance, diag)
    return instance
end

local function isNumber(n)
    return type(n) == "number"
end

local function isTable(t)
    return type(t) == "table"
end

local function isString(s)
    return type(s) == "string"
end

local function isFunction(f)
    return type(f) == "function"
end

local function isVector(v)
    return diag.IsTable(v) and diag.IsNumber(v.x and v.y and v.z)
end

local function isVec3(v)
    return isTable(v) and isNumber(v.x and v.y and v.z) and isFunction(v.trim_inplace)
end

local function formatValues(...)
    local parts = {}

    for _, v in ipairs({...}) do
        local pos = #parts + 1
        local s = {}
        if isString(v) then
            s = string.format("%s", v)
        elseif isNumber(v) then
            s = string.format("%s", tonumber(v))
        elseif isVec3(v) then
            s = string.format("vec3(%s, %s, %s)", v.x, v.y, v.z)
        else
            s = "Unsupported table type"
        end

        table.insert(parts, pos, string.format(" %s", s))
    end

    return table.concat(parts)
end

function diag:AssertIsString(s, msg)
    if self.level >= DiagLevel.OFF then
        assert(isString(s) == "string", msg)
    end
end

function diag:AssertIsTable(t, msg)
    if self.level >= DiagLevel.OFF then
        assert(isTable(t), msg)
    end
end

function diag:AssertIsVec3(v, msg)
    if self.level >= DiagLevel.OFF then
        assert(isTable(v) and isNumber(v.x and v.y and v.z) and isTable(v.unit_z), msg)
    end
end

function diag:AssertNumber(n, msg)
    if self.level >= DiagLevel.OFF then
        assert(isNumber(n), msg)
    end
end

local function getLevelStr(lvl)
    if lvl == DiagLevel.DEBUG then
        return "D"
    elseif lvl == DiagLevel.ERROR then
        return "E"
    elseif lvl == DiagLevel.INFO then
        return "I"
    elseif lvl == DiagLevel.WARNING then
        return "W"
    else
        return "UNKOWN"
    end
end

function diag:print(level, msg, ...)
    if self.level >= level then
        local final = string.format("[%s] %s:%s", getLevelStr(level), msg, formatValues(...))
        system.print(final)
    end
end

function diag:Info(msg, ...)
    self:print(DiagLevel.INFO, msg, ...)
end

function diag:Warning(msg, ...)
    self:print(DiagLevel.WARNING, msg, ...)
end

function diag:Error(msg, ...)
    self:print(DiagLevel.ERROR, msg, ...)
end

function diag:Debug(msg, ...)
    self:print(DiagLevel.DEBUG, msg, ...)
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
