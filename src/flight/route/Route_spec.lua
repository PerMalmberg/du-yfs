require("util/Table")
require("environment"):Prepare()
local Vec3 = require("math/Vec3")
local Route = require("flight/route/Route")

describe("Route #flight", function()
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
        r.AddCoordinate(Vec3.New(1, 2, 3))
        assert.are_equal(1, TableLen(r.Points()))
    end)

    it("Can add a waypoint reference", function()
        local r = Route.New()
        local p = r.AddWaypointRef("a name")
        if p then
            assert.are_equal(1, TableLen(r.Points()))
            assert.is_true(p.HasWaypointRef())
            assert.are_equal("a name", p.WaypointRef())

            p.SetWaypointRef("a new name")
            assert.are_equal("a new name", r.Points()[1].WaypointRef())
        else
            assert.truthy(false)
        end
    end)

    it("Can remove a point", function()
        --[[ local r = Route.New()
        r.AddCurrentPos()
        r.AddCurrentPos()
        assert.are_equal(2, TableLen(r.Points()))
        assert.True(r.RemovePoint(1))
        assert.are_equal(1, TableLen(r.Points()))
        assert.True(r.RemovePoint(1))
        assert.are_equal(0, TableLen(r.Points()))

        r.AddCurrentPos()
        assert.False(r.RemovePoint(0))
        assert.False(r.RemovePoint(2))
        assert.True(r.RemovePoint(1)) ]]
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

    it("Can move points within the route", function()
        local p1 = "::pos{0,2,1.0000,2.0000,3.0000}"
        local p2 = "::pos{0,2,4.0000,5.0000,6.0000}"
        local p3 = "::pos{0,2,7.0000,8.0000,9.0000}"
        local r = Route.New()
        assert.is_not_nil(r.AddPos(p1))
        assert.is_not_nil(r.AddPos(p2))
        assert.is_not_nil(r.AddPos(p3))
        assert.Equal(3, TableLen(r.Points()))
        assert.Equal(p1, r.Points()[1].Pos())
        assert.Equal(p2, r.Points()[2].Pos())
        assert.Equal(p3, r.Points()[3].Pos())

        assert.False(r.MovePoint(0, 0))
        assert.False(r.MovePoint(1, 0))
        assert.False(r.MovePoint(0, 1))
        assert.False(r.MovePoint(1, 1))

        assert.True(r.MovePoint(1, 2))
        assert.Equal(p1, r.Points()[1].Pos())
        assert.Equal(p2, r.Points()[2].Pos())
        assert.Equal(p3, r.Points()[3].Pos())

        assert.True(r.MovePoint(1, 3))
        assert.Equal(p2, r.Points()[1].Pos())
        assert.Equal(p1, r.Points()[2].Pos())
        assert.Equal(p3, r.Points()[3].Pos())

        assert.True(r.MovePoint(3, 1))
        assert.Equal(p3, r.Points()[1].Pos())
        assert.Equal(p2, r.Points()[2].Pos())
        assert.Equal(p1, r.Points()[3].Pos())
    end)
end)
