-- Diagnostic functions

require("Enum")
local library = require("abstraction/Library")()
local Number = require("DiagShape")

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
        core = library.GetCoreUnit(),
        level = DiagLevel.DEBUG,
        shapes = {}
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

local function isBoolean(b)
    return type(b) == "boolean"
end

local function isVec3(v)
    return isTable(v) and isNumber(v.x and v.y and v.z) and isFunction(v.trim_inplace)
end

local function formatValues(...)
    local parts = {}

    for _, v in ipairs({...}) do
        local s = {}
        if isString(v) then
            s = string.format("%s", v)
        elseif isNumber(v) then
            s = string.format("%s", tonumber(v))
        elseif isVec3(v) then
            s = string.format("vec3(%s, %s, %s)", v.x, v.y, v.z)
        elseif isBoolean(v) then
            if v then
                s = "true"
            else
                s = "false"
            end
        else
            s = "Unsupported table type:" .. type(v)
        end

        table.insert(parts, #parts + 1, string.format(" %s", s))
    end

    return table.concat(parts)
end

local function formatTypeMessage(parameterName, parameter, wantedTypeName, functionName)
    return string.format("%s in %s must be %s, got %s", parameterName, functionName, wantedTypeName, type(parameter))
end

function diag:AssertIsString(s, parameterName, functionName)
    assert(isString(s) == "string", formatTypeMessage(parameterName, s, "string", functionName))
end

function diag:AssertIsTable(t, parameterName, functionName)
    assert(isTable(t), formatTypeMessage(parameterName, t, "table", functionName))
end

function diag:AssertIsVec3(v, parameterName, functionName)
    assert(isTable(v) and isNumber(v.x and v.y and v.z) and isFunction(v.trim_inplace), formatTypeMessage(parameterName, v, "vec3", functionName))
end

function diag:AssertIsNumber(n, parameterName, functionName)
    assert(isNumber(n), formatTypeMessage(parameterName, n, "number", functionName))
end

function diag:AssertIsFunction(f, parameterName, functionName)
    assert(isFunction(f), formatTypeMessage(parameterName, f, "function", functionName))
end

function diag:Fail(msg)
    assert(false, msg)
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

---Draws a number
---@param number number
---@param worldPos vec3
function diag:DrawNumber(number, worldPos)
    local s = self.shapes[number]
    if s ~= nil then
        s.worldPos = worldPos
    else
        self.shapes[number] = Number(library.GetCoreUnit(), number, worldPos)
    end
end

function diag:RemoveNumber(number)
    local s = self.shapes[number]
    if s then
        s:Remove()
        self.shapes[number] = nil
    end
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
