local env    = require("environment")
local assert = require("luassert")
env.Prepare()
local universe = require("universe/Universe").Instance()
local stub = require("luassert.stub")
require("util/Table")
local ConstructMock = require("mocks/ConstructMock")
local constants = require("YFSConstants")

local function runTicks()
    for i = 1, 1000, 1 do
        system:triggerEvent("onUpdate")
    end
end

---@param controller RouteController
local function clearRoutes(controller)
    for _, name in ipairs(controller.GetRouteNames()) do
        controller.DeleteRoute(name)
    end
end

describe("RouteController #flight", function()
    require("api-mockup/databank")
    local RouteController = require("flight/route/RouteController")

    local BufferedDB = require("storage/BufferedDB")

    local dataBank = Databank()

    stub(dataBank, "getKeyList")
    stub(dataBank, "getStringValue")

    dataBank.getKeyList.on_call_with().returns({})
    dataBank.getStringValue.on_call_with(RouteController.NAMED_POINTS).returns({})

    local db = BufferedDB.New(dataBank)
    db.BeginLoad()
    local c = RouteController.Instance(db)

    while not db:IsLoaded() do
        runTicks()
    end

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
        local p = r.AddWaypointRef("a point")
        assert.is_not_nil(p)
        p.Options().Set("some option", "some value")

        assert.are_equal("some value", r.Points()[1].Options().Get("some option"))

        assert.is_not_nil(r.AddWaypointRef("a second point"))
        assert.is_true(c.SaveRoute())
        r = c.EditRoute("a route")
        assert.are_equal(2, #r.Points())
        assert.are_equal("a point", r.Points()[1].WaypointRef())
        assert.are_equal("some value", r.Points()[1].Options().Get("some option"))
    end)

    it("Can handle missing waypoints", function()
        local r = c.CreateRoute("a route2")
        assert.is_not_nil(r.AddWaypointRef("a non exsting point"))
        c.SaveRoute()
        r = c.EditRoute("a route2")
        assert.is_nil(r)
    end)

    it("It doesn't activate non-existing routes", function()
        assert.is_false(c.ActivateRoute(""))
    end)

    it("Can adjust a route to ensure it is traveled in the right direction", function()
        clearRoutes(c)

        local positions = {
            "::pos{0,2,49.9340,160.4566,0}",
            "::pos{0,2,49.9340,160.4566,10}",
            "::pos{0,2,49.9340,160.4566,20}",
            "::pos{0,2,49.9340,160.4566,30}",
            "::pos{0,2,49.9340,160.4566,40}",
        }


        assert.is_true(c.StoreWaypoint("A", positions[1]))
        assert.is_true(c.StoreWaypoint("B", positions[2]))
        assert.is_true(c.StoreWaypoint("C", positions[3]))
        assert.is_true(c.StoreWaypoint("D", positions[4]))
        assert.is_true(c.StoreWaypoint("E", positions[5]))

        local r = c.CreateRoute("name")
        assert.is_not_nil(r.AddWaypointRef("A"))
        assert.is_not_nil(r.AddWaypointRef("B"))
        assert.is_not_nil(r.AddWaypointRef("C"))
        assert.is_not_nil(r.AddWaypointRef("D"))
        assert.is_not_nil(r.AddWaypointRef("E"))
        assert.is_true(c.SaveRoute())

        -- Run it from start to end
        ConstructMock.Instance().SetContructPostion(universe.ParsePosition(positions[1]).Coordinates())
        assert.is_true(c.ActivateRoute("name"))
        r = c.CurrentRoute()

        local p = r.Next()
        assert.are_equal("A", p.WaypointRef())
        p = r.Next()
        assert.are_equal("B", p.WaypointRef())
        p = r.Next()
        assert.are_equal("C", p.WaypointRef())
        p = r.Next()
        assert.are_equal("D", p.WaypointRef())
        p = r.Next()
        assert.are_equal("E", p.WaypointRef())
        assert.is_nil(r.Next())

        -- Now start in the middle, still moving to last
        ConstructMock.Instance().SetContructPostion(universe.ParsePosition(positions[3]).Coordinates())
        assert.is_true(c.ActivateRoute("name"))
        r = c.CurrentRoute()

        -- First point is the end of the first leg
        p = r.Next()
        assert.are_equal("C", p.WaypointRef())
        p = r.Next()
        assert.are_equal("D", p.WaypointRef())
        p = r.Next()
        assert.are_equal("E", p.WaypointRef())
        assert.is_nil(r.Next())

        -- Run it from last point
        ConstructMock.Instance().SetContructPostion(universe.ParsePosition(positions[5]).Coordinates())
        assert.is_true(c.ActivateRoute("name"))
        r = c.CurrentRoute()

        p = r.Next()
        assert.are_equal("E", p.WaypointRef())
        assert.is_nil(r.Next())

        -- Run it backwards
        ConstructMock.Instance().SetContructPostion(universe.ParsePosition(positions[5]).Coordinates())
        assert.is_true(c.ActivateRoute("name", 1))
        r = c.CurrentRoute()

        local p = r.Next()
        assert.are_equal("E", p.WaypointRef())
        p = r.Next()
        assert.are_equal("D", p.WaypointRef())
        p = r.Next()
        assert.are_equal("C", p.WaypointRef())
        p = r.Next()
        assert.are_equal("B", p.WaypointRef())
        p = r.Next()
        assert.are_equal("A", p.WaypointRef())
        assert.is_nil(r.Next())

        print("------------")
        -- Run it backwards to next to last point
        ConstructMock.Instance().SetContructPostion(universe.ParsePosition(positions[5]).Coordinates())
        assert.is_true(c.ActivateRoute("name", 4))
        r = c.CurrentRoute()

        local p = r.Next()
        assert.are_equal("E", p.WaypointRef())
        p = r.Next()
        assert.are_equal("D", p.WaypointRef())
        assert.is_nil(r.Next())


        ConstructMock.Instance().ResetContructPostion()
    end)

    it("Can delete a waypoint", function()
        local count = TableLen(c.GetWaypoints())
        c.StoreWaypoint("todelete", "::pos{0,2,2.9093,65.4697,34.7073}")
        assert.are_equal(count + 1, TableLen(c.GetWaypoints()))
        assert.is_true(c.DeleteWaypoint("todelete"))
        assert.are_equal(count, TableLen(c.GetWaypoints()))
    end)

    it("Can do pagenation", function()
        clearRoutes(c)
        assert.are_equal(0, c.Count())

        for i = 1, 11, 1 do
            c.CreateRoute(string.format("route%2d", i)) -- Make route names alphabetically sortable
            c.SaveRoute()
        end

        assert.are_equal(11, c.Count())
        assert.are_equal(3, c.GetPageCount(5))

        local five = c.GetRoutePage(1, 5)
        assert.are_equal(5, TableLen(five))
        assert.equal("route 1", five[1])
        assert.equal("route 2", five[2])
        assert.equal("route 3", five[3])
        assert.equal("route 4", five[4])
        assert.equal("route 5", five[5])

        five = c.GetRoutePage(2, 5)
        assert.are_equal(5, TableLen(five))
        assert.equal("route 6", five[1])
        assert.equal("route 7", five[2])
        assert.equal("route 8", five[3])
        assert.equal("route 9", five[4])
        assert.equal("route10", five[5])

        local one = c.GetRoutePage(3, 5)
        assert.are_equal(1, TableLen(one))
        assert.equal("route11", one[1])

        -- Get the last page
        local pastEnd = c.GetRoutePage(10, 5)
        assert.are_equal(1, TableLen(pastEnd))
    end)

    it("Refuses to activate a route if outside limit", function()
        local pointOutsideRoute = universe.ParsePosition("::pos{0,2,49.9336,160.4417,50.3573}")
        local pointInsideRoute = universe.ParsePosition("::pos{0,2,49.9347,160.4801,50.2793}")
        ConstructMock.Instance().SetContructPostion(pointOutsideRoute.Coordinates())

        local positions = {
            "::pos{0,2,49.9340,160.4566,50.3272}",
            "::pos{0,2,49.9348,160.4848,50.2807}",
            "::pos{0,2,49.9338,160.5161,50.2451}"
        }

        local r = c.CreateRoute("refuse")
        for _, value in ipairs(positions) do
            r.AddPos(value)
        end

        assert.True(c.SaveRoute())
        local margin = constants.route.routeStartDistanceLimit
        assert.False(c.ActivateRoute("refuse", 0, margin))
        assert.False(c.ActivateRoute("refuse", 0, margin))

        ConstructMock.Instance().SetContructPostion(pointInsideRoute.Coordinates())
        assert.True(c.ActivateRoute("refuse"))

        ConstructMock.Instance().ResetContructPostion()
    end)

    --[[it("Can skip skippable points", function()
        clearRoutes(c)
        assert.are_equal(0, c.Count())

        ---@param pos string
        ---@param skippable boolean
        ---@return Point
        local function newPoint(pos, skippable)
            local opt = PointOptions.New()
            opt.Set(PointOptions.SKIPPABLE, skippable)
            local p = Point.New(pos, nil, opt)
            return p
        end

        local name = "route_with_skippable_points"
        local r = c.CreateRoute(name)
        r.AddPoint(newPoint("::pos{0,1,1,1}", false))
        r.AddPoint(newPoint("::pos{0,1,1,2}", true))
        r.AddPoint(newPoint("::pos{0,1,1,3}", true))
        r.AddPoint(newPoint("::pos{0,1,1,4}", false))
        r.AddPoint(newPoint("::pos{0,1,1,5}", true))
        r.AddPoint(newPoint("::pos{0,1,1,6}", false))
        c.SaveRoute()

        -- Activate the route to the fifth point, which is also skippable.
        assert.True(c.ActivateRouteToWaypoint(name, 5))
        r = c.CurrentRoute()
        -- We expect a total of three points in the route and the last one to be the same as the one we added at the fifth position.
        assert.is_not_nil(r.Next())
        assert.is_not_nil(r.Next())
        local last = r.Next()
        assert.is_not_nil(last)
        assert.Equal("::pos{0,1,1,5}", last.Pos())
        assert.is_nil(r.Next())
    end]]
end)
