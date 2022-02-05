local lu = require("luaunit")
local constants = require("Constants")
local AxisControl = require("AxisControl")

Test = {}

function Test:testTargetMovementDirection()
    local ac = AxisControl()

    lu.assertEquals(ac:TargetMovementDirection(-0.5, 0.25), constants.direction.clockwise)
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
