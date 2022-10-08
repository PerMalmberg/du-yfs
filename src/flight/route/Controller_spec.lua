local env = require("environment")
local assert = require("luassert")
local stub = require("luassert.stub")
require("util/Table")

local function runTicks()
    for i = 1, 1000, 1 do
        system:triggerEvent("onUpdate")
    end
end

describe("Controller", function()
    env.Prepare()
    require("api-mockup/databank")
    local Controller = require("flight/route/Controller")

    local BufferedDB = require("storage/BufferedDB")

    local dataBank = Databank()

    stub(dataBank, "getKeyList")
    stub(dataBank, "getStringValue")

    dataBank.getKeyList.on_call_with().returns({})
    dataBank.getStringValue.on_call_with(Controller.NAMED_POINTS).returns({})

    local db = BufferedDB.New(dataBank)
    db:BeginLoad()
    local c = Controller.Instance(db)

    while not db:IsLoaded() do
        runTicks()
    end

    it("Can create a route", function()
        assert.is_nil(c.CreateRoute(nil))


        c.CreateRoute("test")
        local r = c.CurrentEdit()
        assert.is_not_nil(r)
        assert.are_equal(0, TableLen(r.Points()))

        r.AddCurrentPos()
        r.AddCurrentPos()

        assert.are_equal(2, TableLen(r.Points()))
        c.SaveRoute()

        c.CreateRoute("test2")
        r = c.CurrentEdit()
        r.AddCurrentPos()
        assert.are_equal(1, TableLen(r.Points()))
        c.SaveRoute()

        c.LoadRoute("test")
        r = c.CurrentEdit()
        assert.are_equal(2, TableLen(r.Points()))

        assert.is_nil(c.CurrentRoute())
        c.ActivateRoute("test")
        r = c.CurrentRoute()
        assert.are_equal(2, TableLen(r.Points()))

        c.ActivateRoute("test2")
        r = c.CurrentRoute()
        assert.are_equal(1, TableLen(r.Points()))
    end)

    it("Can delete routes", function()
        local count = c.Count()
        c.CreateRoute("todelete")
        assert.are_equal(count, c.Count()) -- Not yet saved so not counted
        c.SaveRoute()
        assert.are_equal(count + 1, c.Count())
        c.DeleteRoute("todelete")
        assert.are_equal(count, c.Count())
    end)

    it("Cannot load route that does not exist", function()
        assert.is_nil(c.LoadRoute("doesn't exist"))
    end)

    it("Can get waypoints", function()
        assert.are_equal(0, TableLen(c.GetWaypoints()))
        assert.is_true(c.StoreWaypoint("b", "::pos{0,2,2.9093,65.4697,34.7070}"))
        assert.is_true(c.StoreWaypoint("a", "::pos{0,2,2.9093,65.4697,34.7070}"))
        assert.is_true(c.StoreWaypoint("c", "::pos{0,2,2.9093,65.4697,34.7070}"))
        assert.are_equal(3, TableLen(c.GetWaypoints()))
        assert.are_equal("a", c.GetWaypoints()[1].name)
        assert.are_equal("b", c.GetWaypoints()[2].name)
        assert.are_equal("c", c.GetWaypoints()[3].name)

    end)

    it("Can load routes with waypoints in it", function()
        assert.is_true(c.StoreWaypoint("a point", "::pos{0,2,2.9093,65.4697,34.7070}"))
        assert.is_true(c.StoreWaypoint("a second point", "::pos{0,2,2.9093,65.4697,34.7070}"))
        local r = c.CreateRoute("a route")
        assert.is_not_nil(r.AddWaypointRef("a point"))
        assert.is_not_nil(r.AddWaypointRef("a second point"))
        c.SaveRoute()
        r = c.LoadRoute("a route")
        assert.are_equal(2, #r.Points())
    end)

    it("Can handle missing waypoints", function()
        local r = c.CreateRoute("a route")
        assert.is_not_nil(r.AddWaypointRef("a non exsting point"))
        c.SaveRoute()
        r = c.LoadRoute("a route")
        assert.is_nil(r)
    end)

    it("It doesn't activate non-existing routes", function()
        assert.is_false(c.ActivateRoute(nil))
    end)
end)
