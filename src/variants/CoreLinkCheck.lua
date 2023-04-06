local log = require("debug/Log")()

---Ensures that the core is linked and returns true if the control unit is an ECU
---@return boolean
---@return boolean
local function ensureCoreLink()
    local unitInfo = system.getItem(unit.getItemId())
    local isECU = unitInfo.displayNameWithSize:lower():match("emergency")

    local linked = library.getCoreUnit() ~= nil
    if not linked then
        log:Error(unitInfo.displayNameWithSize, " must be linked to the core.")
    end

    return linked, isECU
end

return ensureCoreLink
