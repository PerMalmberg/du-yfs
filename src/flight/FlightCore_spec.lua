local env = require("environment")
env.Prepare()

require("abstraction/Vehicle")
require("GlobalTypes")

local FlightCore = require("flight/FlightCore")

describe("FlightCore #flight", function()
    it("Can create Waypoint from point", function()
        local o = PointOptions.New()
        o.Set(PointOptions.MAX_SPEED, 1000)
        o.Set(PointOptions.FINAL_SPEED, 1)
        o.Set(PointOptions.LOCK_DIRECTION, { Vec3.New(1, 2, 3):Unpack() })
        o.Set(PointOptions.MARGIN, 456)
        local p = Point.New("::pos{0,2,2.9093,65.4697,34.7070}", nil, o)

        local wp = FlightCore.CreateWPFromPoint(p, false, 0)
        assert.are_equal(1000, wp.MaxSpeed())
        assert.are_equal(1, wp.FinalSpeed())
        assert.is_true(wp.IsYawLocked())
        assert.are_equal(456, wp.Margin())
    end)

    it("Can create Waypoint from point, with last in route", function()
        local o = PointOptions.New()
        o.Set(PointOptions.FINAL_SPEED, 1)
        local p = Point.New("::pos{0,2,2.9093,65.4697,34.7070}", nil, o)

        local wp = FlightCore.CreateWPFromPoint(p, true, 0)
        assert.are_equal(0, wp.FinalSpeed())
    end)
end)
