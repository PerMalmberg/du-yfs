require("util/Table")
require("environment"):Prepare()
local Vec3 = require("cpml/vec3")
local Route = require("flight/route/Route")

describe("Route", function()
    it("Can create a route with points", function()
        local r = Route.New()
        r.AddCurrentPos()
        assert.are_equal(1, TableLen(r.Points()))
        r.Clear()
        assert.are_equal(0, TableLen(r.Points()))
    end)

    it("Can add position strings", function()
        local r = Route.New()
        assert.is_not_nil(r.AddPos("::pos{0,2,61.1382,78.4574,39.6572}"))
        assert.are_equal(1, TableLen(r.Points()))
        assert.is_nil(r.AddPos("::pos{}"))
        assert.are_equal(1, TableLen(r.Points()))
    end)

    it("Can add a coordinate", function()
        local r = Route.New()
        r.AddCoordinate(Vec3(1, 2, 3))
        assert.are_equal(1, TableLen(r.Points()))
    end)

    it("Can add a waypoint reference", function()
        local r = Route.New()
        local p = r.AddWaypointRef("a name")
        assert.are_equal(1, TableLen(r.Points()))
        assert.is_true(p.HasWaypointRef())
        assert.are_equal("a name", p.WaypointRef())

        p.SetWaypointRef("a new name")
        assert.are_equal("a new name", r.Points()[1].WaypointRef())
    end)

    it("Can iterate through the points", function()
        local r = Route.New()
        for i = 1, 10, 1 do
            r.AddCurrentPos()
        end

        assert.are_equal(10, TableLen(r.Points()))

        for i = 1, 10, 1 do
            assert.is_not_nil(r.Next())
        end

        assert.is_nil(r.Next())
    end)
end)
