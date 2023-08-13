local log = require("debug/Log").Instance()
local su = require("util/StringUtil")
local _ = require("util/Table")

---@class Access
---@field CanExecute fun(command:string):boolean
---@field AllowsManualControl fun():boolean
---@field AllowedRoute fun(routeName:string)
---@field DisallowRoute fun(routeName:string)
---@field MayStartRoute fun(routeName:string):boolean
---@field New fun(db:BufferedDB):Access

local Access = {}
Access.__index = Access
local instance

---@param db BufferedDB
---@param cmdLine CommandLine
---@return Access
function Access.New(db, cmdLine)
    if instance then return instance end

    local s = {}
    local ROUTES = "allowedRoutes"
    local MANUAL = "allowManualControl"

    ---@return boolean
    local function isConstructOwner()
        ---@type {id:integer, isOrganization:boolean}
        local constructOwner = construct.getOwner()

        if constructOwner.isOrganization then
            for _, v in ipairs(player.getOrgIds()) do
                if v == constructOwner.id then
                    return true
                end
            end
            return false
        else
            return constructOwner.id == player.getId()
        end
    end

    local isOwner = isConstructOwner()

    ---@param command string
    ---@return boolean
    function s.CanExecute(command)
        if isOwner then return true end

        -- Disallow everything but route-activate
        return su.StartsWith(command, "route-activate")
    end

    ---@return boolean
    function s.AllowsManualControl()
        if isOwner then return true end
        return db.Get(MANUAL, false)
    end

    ---@param routeName string
    function s.AllowRoute(routeName)
        local routes = db.Get(ROUTES, {})
        routes[routeName] = true
        db.Put(ROUTES, routes or {})
    end

    ---@param routeName string
    function s.DisallowRoute(routeName)
        local routes = db.Get(ROUTES, {})
        routes[routeName] = nil
        db.Put(ROUTES, routes or {})
    end

    ---@param routeName string
    function s.MayStartRoute(routeName)
        local routes = db.Get(ROUTES, {})
        log.Info(routes)
        local mayStart = isOwner or (routes and routes[routeName] ~= nil)

        if not mayStart then
            log.Error("Not authorized to start route '", routeName, "'")
        end

        return mayStart
    end

    instance = setmetatable(s, Access)

    cmdLine.Accept("allow-route",
        ---@param data {commandValue:string}
        function(data)
            s.AllowRoute(data.commandValue)
        end).AsString().Mandatory()

    cmdLine.Accept("disallow-route",
        ---@param data {commandValue:string}
        function(data)
            s.DisallowRoute(data.commandValue)
        end).AsString().Mandatory()

    cmdLine.Accept("allowed-routes",
        ---@param _ {commandValue:string}
        function(_)
            local allowed = db.Get(ROUTES, {})
            ---@cast allowed table
            if TableLen(allowed) > 0 then
                log.Info("Allowed routes:")
                for k, v in pairs(allowed) do
                    log.Info(k)
                end
            else
                log.Info("No allowed routes")
            end
        end).AsEmpty()

    cmdLine.Accept("allow-manual-control", function(data)
        db.Put(MANUAL, true)
    end)

    cmdLine.Accept("disallow-manual-control", function(data)
        db.Put(MANUAL, false)
    end)

    return instance
end

return Access
