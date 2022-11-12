local env = require("environment")
env.Prepare()

local FlightCore = require("flight/FlightCore")
local Point = require("flight/route/Point")
local PointOptions = require("flight/route/PointOptions")
local Waypoint = require("flight/Waypoint")
local Vec3 = require("math/Vec3")

describe("FlightCore", function()
    it("Can create Waypoint from point", function()
        local o = PointOptions.New()
        o.Set(PointOptions.MAX_SPEED, 1000)
        o.Set(PointOptions.FINAL_SPEED, 1)
        o.Set(PointOptions.LOCK_DIRECTION, { Vec3.New(1, 2, 3):Unpack() })
        o.Set(PointOptions.MARGIN, 456)
        o.Set(PointOptions.PRECISION, true)
        o.Set(PointOptions.USE_WINGS, true)
        local p = Point.New("::pos{0,2,2.9093,65.4697,34.7070}", nil, o)

        local wp = FlightCore.CreateWPFromPoint(p, false)
        assert.are_equal(1000, wp.MaxSpeed())
        assert.are_equal(1, wp.FinalSpeed())
        assert.are_equal(Vec3.New(1, 2, 3), wp.YawPitchDirection())
        assert.is_true(wp.DirectionLocked())
        assert.are_equal(456, wp.Margin())
        assert.are_equal(true, wp.GetPrecisionMode())
    end)

    it("Can create Waypoint from point, with last in route", function()
        local o = PointOptions.New()
        o.Set(PointOptions.FINAL_SPEED, 1)
        local p = Point.New("::pos{0,2,2.9093,65.4697,34.7070}", nil, o)

        local wp = FlightCore.CreateWPFromPoint(p, true)
        assert.are_equal(0, wp.FinalSpeed())
    end)
end)
