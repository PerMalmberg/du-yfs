local log = require("debug/Log").Instance()
local su = require("util/StringUtil")
local _ = require("util/Table")

---@alias AdminData table<string, boolean>
---@alias ConstructOwner {id:integer, isOrganization:boolean}

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
    local ORG_ADMIN = "orgAdmin"
    local ADMIN = "adminList"

    ---@param constructOwner integer
    ---@return boolean
    local function isOrgAdmin(constructOwner)
        -- Members of the owning organization are admins by default
        if db.Boolean(ORG_ADMIN, true) then
            for _, v in ipairs(player.getOrgIds()) do
                if v == constructOwner then
                    return true
                end
            end
        end

        return false
    end

    local function isInAdminList()
        local name = player.getName()
        local admins = db.Get(ADMIN, {})
        ---@cast admins AdminData
        for k, _ in pairs(admins) do
            if k == name then
                return true
            end
        end

        return false
    end

    ---@return ConstructOwner
    local function getOwner()
        ---@type {id:integer, isOrganization:boolean}
        return construct.getOwner()
    end

    ---@return boolean
    local function isConstructOwner()
        local owner = getOwner()
        return owner.isOrganization and isOrgAdmin(owner.id) or owner.id == player.getId()
    end

    local function isAdmin()
        return isConstructOwner() or isInAdminList()
    end

    if isAdmin() then
        log.Info(player.getName(), " is an administrator")
    end

    ---@param command string
    ---@return boolean
    function s.CanExecute(command)
        -- Disallow everything but route-activate
        return isAdmin() or su.StartsWith(command, "route-activate")
    end

    ---@return boolean
    function s.AllowsManualControl()
        return isAdmin() or db.Boolean(MANUAL, false)
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
        local mayStart = (routes and routes[routeName] ~= nil) or isAdmin()

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

    cmdLine.Accept("print-allowed-routes",
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

    local function checkOrgOwner()
        local owner = getOwner()
        if not owner.isOrganization then
            log.Error("Owner is not an organization")
            return false
        end
        return true
    end

    cmdLine.Accept("allow-org-admin", function(data)
        if checkOrgOwner() then
            db.Put(ORG_ADMIN, true)
            log.Info("Owning organization is now considered an administrator")
        end
    end)

    cmdLine.Accept("disallow-org-admin", function(data)
        if not checkOrgOwner() then
            return
        end

        if not isInAdminList() then
            log.Error(
                "Removing the orginaization as an admin would lock you out since you're not in the administrator list!")
            return
        end

        db.Put(ORG_ADMIN, false)
        log.Info("Owning organization is no longer considered an administrator")
    end)

    ---@param name string
    ---@param value? boolean
    local function setAdmin(name, value)
        local admins = db.Get(ADMIN, {})
        ---@cast admins AdminData

        local existed = admins[name] ~= nil

        admins[name] = value or nil
        db.Put(ADMIN, admins)

        if value then
            log.Info(name, " added to admin list")
        elseif existed then
            log.Info(name, " removed from admin list")
        else
            log.Error(name, " not in the admin list")
        end
    end

    cmdLine.Accept("add-admin",
        ---@param data {commandValue:string}
        function(data)
            setAdmin(data.commandValue, true)
        end).AsString().Mandatory()

    cmdLine.Accept("remove-admin",
        ---@param data {commandValue:string}
        function(data)
            setAdmin(data.commandValue)
        end).AsString().Mandatory()

    cmdLine.Accept("print-admins", function(_)
        local admins = db.Get(ADMIN, {})
        ---@cast admins AdminData
        if TableLen(admins) > 0 then
            log.Info("Administrators:")
            for k, v in pairs(admins) do
                log.Info(k)
            end
        else
            log.Info("No named administrators")
        end
        if db.Boolean(ORG_ADMIN, false) then
            log.Info("Members of owning orgs are all administrators")
        end
    end)

    return instance
end

return Access
