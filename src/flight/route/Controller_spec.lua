local env = require("environment")
require("util/Table")

local function runTicks()
    for i = 1, 1000, 1 do
        system:triggerEvent("onUpdate")
    end
end

describe("Controller", function()
    env.Prepare()
    require("api-mockup/databank")

    local BufferedDB = require("storage/BufferedDB")

    it("Can create a route", function()
        local Controller = require("flight/route/Controller")


        local db = BufferedDB.New(Databank())
        db:BeginLoad()
        local c = Controller.Instance(db)

        while not db:IsLoaded() do
            runTicks()
        end

        c.CreateRoute("test")
        local r = c.CurrentEdit()
        assert.is_not_nil(r)
        assert.are_equal(0, TableLen(r.Points()))

        r.AddCurrentPos()
        r.AddCurrentPos()

        assert.are_equal(2, TableLen(r.Points()))
        c.SaveRoute()
        assert.is_nil(c.CurrentEdit())
    end)
end)
