local env = require("environment")
env.Prepare()

local AdjustmentTracker = require("flight/AdjustmentTracker")

it("Can track increase and decrease #flight", function()
    local t = AdjustmentTracker.New()
    assert.equal(1, t.TrackDistance(10))
    assert.equal(1, t.TrackDistance(11))
    assert.equal(0, t.TrackDistance(11))
    assert.equal(-1, t.TrackDistance(9))
    assert.equal(-1, t.TrackDistance(8))
    assert.equal(-1, t.TrackDistance(7))
end)
