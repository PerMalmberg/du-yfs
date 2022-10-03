local Point = require("flight/route/Point")
local PointOptions = require("flight/route/PointOptions")

describe("Point", function()
    local posString = "::pos{0,0,0,0,0}"
    local opt = PointOptions:New()
    opt:Set(PointOptions.FINAL_SPEED, 1)
    opt:Set(PointOptions.MAX_SPEED, 2)
    opt:Set(PointOptions.LOCK_DIRECTION, true)
    opt:Set(PointOptions.MARGIN, 3)
    opt:Set(PointOptions.PRECISION, true)
    opt:Set(PointOptions.USE_WINGS, true)
    opt:Get()

    it("returns what is passed in", function()
        local point = Point:New(posString,"named reference", opt)
        assert.are.equal(posString, point.Pos())
        assert.is_true(point:HasWaypointRef())
        assert.are.equal("named reference", point:WaypointRef())
        assert.are.equal(opt, point:Options())
    end)

    it("persists correctly", function()
        local point = Point:New(posString,"named reference", opt)
        local data = point:Persist()
        assert.are.equal(posString, data.pos)
        assert.are.equal("named reference", data.waypointRef)
        assert.are.equal(1, data.options[PointOptions.FINAL_SPEED])
        assert.are.equal(2, data.options[PointOptions.MAX_SPEED])
        assert.are.equal(true, data.options[PointOptions.LOCK_DIRECTION])
        assert.are.equal(3, data.options[PointOptions.MARGIN])
        assert.are.equal(true, data.options[PointOptions.PRECISION])
        assert.are.equal(true, data.options[PointOptions.USE_WINGS])
    end)
end)