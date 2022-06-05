local lu = require("luaunit")
local EngineGroup = require("EngineGroup")

Test = {}

function Test:testEmptyIntersection()
    local eg = EngineGroup()
    eg:Add("thrust")
    lu.assertEquals(eg:Intersection(), "thrust")
end

function Test:testIntersection()
    local eg = EngineGroup.new("ALL")
    lu.assertNotIsNil(eg)
    eg:Add("thrust")
    lu.assertEquals(eg:Intersection(), "ALL,thrust")
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())