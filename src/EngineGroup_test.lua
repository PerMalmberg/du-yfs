local lu = require("luaunit")
local EngineGroup = require("EngineGroup")

Test = {}

function Test:testEmptyUnion()
    local eg = EngineGroup()
    eg:Add("thrust")
    lu.assertEquals(eg:Union(), "thrust")
end

function Test:testUnion()
    local eg = EngineGroup.new("ALL")
    lu.assertNotIsNil(eg)
    eg:Add("thrust")
    lu.assertEquals(eg:Union(), "ALL,thrust")
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
