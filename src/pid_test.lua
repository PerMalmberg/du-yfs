local lu = require("luaunit")
local Pid = require("pid")

Test = {}

function Test:testPid()
    local p = Pid(0, 0.3, 0.2)

    for i = 100, -70, -0.1 do
        if i > 0 then
            p:inject(i)
        else
            p:inject(0)
        end
        io.write(i .. " " .. p:get() .. "\n")
    end
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
