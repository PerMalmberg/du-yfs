local log = require("debug/Log")()
local v = require("version_out")

log:Info(v.APP_NAME)
log:Info(v.APP_VERSION)

if not library.getCoreUnit() then
    log:Error("Please link the Core to the control unit.")
    return
end

log:Info("Unlimited version")
local start = require("Start")
start()
