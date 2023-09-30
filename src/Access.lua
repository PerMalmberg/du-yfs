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

    ---@return ConstructOwner
    local function getOwner()
        ---@type {id:integer, isOrganization:boolean}
        return construct.getOwner()
    end

    local function isOwnedByAnOrg()
        return getOwner().isOrganization
    end

    local function isOrgAnAdmin()
        -- By default owning org is an admin
        return isOwnedByAnOrg() and db.Boolean(ORG_ADMIN, true)
    end

    local function isMemberOfOwningOrg()
        local owner = getOwner()
        if owner.isOrganization then
            for _, v in ipairs(player.getOrgIds()) do
                if v == owner.id then
                    return true
                end
            end
        end
        return false
    end

    local function isSingleOwner()
        local owner = getOwner()
        return (not owner.isOrganization) and owner.id == player.getId()
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

    local function isAdmin()
        return isSingleOwner() or
            (isOwnedByAnOrg() and isMemberOfOwningOrg() and isOrgAnAdmin()) or
            isInAdminList()
    end

    if isAdmin() then
        log.Info(player.getName(), " is an admin")
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
        end).AsString().Must()

    cmdLine.Accept("disallow-route",
        ---@param data {commandValue:string}
        function(data)
            s.DisallowRoute(data.commandValue)
        end).AsString().Must()

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
            log.Info("Owning organization is now considered an admin")
        end
    end)

    cmdLine.Accept("disallow-org-admin", function(data)
        if not checkOrgOwner() then
            return
        end

        if not isInAdminList() then
            log.Error(
                "Removing the orginaization as an admin would lock yourself out since you're not in the admin list, aborting!")
            return
        end

        db.Put(ORG_ADMIN, false)
        log.Info("Owning organization is no longer considered an admin")
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
            log.Error(name, " is not in the admin list")
        end
    end

    cmdLine.Accept("add-admin",
        ---@param data {commandValue:string}
        function(data)
            setAdmin(data.commandValue, true)
        end).AsString().Must()

    cmdLine.Accept("remove-admin",
        ---@param data {commandValue:string}
        function(data)
            -- Can't remove yourself if org owned and org is not an admin, that would lock you out
            local isAdminViaOrg = isMemberOfOwningOrg() and isOrgAnAdmin()
            local isAssignedAdmin = isInAdminList()

            if data.commandValue == player.getName() then
                if not (isAdminViaOrg and isAssignedAdmin) then
                    log.Error(
                        "Removing yourself as an admin would lock yourself out, aborting!")
                    return
                end
            end

            setAdmin(data.commandValue)
        end).AsString().Must()

    cmdLine.Accept("print-admins", function(_)
        local admins = db.Get(ADMIN, {})
        ---@cast admins AdminData
        if TableLen(admins) > 0 then
            log.Info("Admins:")
            for k, v in pairs(admins) do
                log.Info(k)
            end
        else
            log.Info("No named admins")
        end
        if isOrgAnAdmin() then
            log.Info("Members of owning orgs are all admins")
        end
    end)

    return instance
end

return Access
