local offline = require("screen/offline_layout")
local driver = require("Driver").Instance()
driver.SetOfflineLayout(offline)
driver.Render(10, false)
