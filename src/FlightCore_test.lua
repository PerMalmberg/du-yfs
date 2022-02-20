local lu = require("luaunit")
local FlightCore = require("FlightCore")
local EngineGroup = require("EngineGroup")
local vec3 = require("cpml/vec3")
local Pid = require("cpml/pid")

Test = {}

local fc = FlightCore()

function Test:testAcceleration()
    local all = EngineGroup("ALL")
    fc:Flush()
end

function Test:testPid()
    local pid = Pid(0.2, 0, 10)

    for i = 1, 100, .1 do
        local input = math.sin(i)
        pid:inject(input)
        io.write(input .. ": " .. tostring(pid:get() .. "\n"))
    end
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
