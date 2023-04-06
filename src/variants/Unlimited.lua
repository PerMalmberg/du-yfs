local log = require("debug/Log")()
local v = require("version_out")

log:Info(v.APP_NAME)
log:Info(v.APP_VERSION)
log:Info("Unlimited version")

local linked, isECU = require("variants/CoreLinkCheck")()
if linked then
    local start = require("Start")
    start(isECU)
else
    unit.exit()
end
