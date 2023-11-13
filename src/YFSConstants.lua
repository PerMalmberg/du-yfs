local Vec3 = require("math/Vec3")

local constants = {
    ticksPerSecond = 60.0,
    flushTick = 1 / 60.0,
    universe = {
        up = Vec3.New(0, 1, 0),
        forward = Vec3.New(1, 0, 0),
        right = Vec3.New(0, 0, 1)
    },
    direction = {
        counterClockwise = 1,
        clockwise = -1,
        rightOf = 1,
        leftOf = -1,
        still = 0
    },
    flight = {
        speedPid = {
            p = 5,
            i = 0.005,
            d = 100,
            a = 0.99
        },
        axis = {
            light = {
                p = 10,
                i = 0,
                d = 800,
                a = 0.1
            },
            heavy = {
                p = 6,
                i = 1,
                d = 1600,
                a = 0.1
            }
        },
        throttleStep = 10,                   -- percent
        defaultMargin = 0.1,                 -- meter
        defaultStartEndMargin = 0.3,         -- meter
        defaultTurnAngle = 1,                -- degrees
        lightConstructMassThreshold = 10000, -- ten tons
        minimumPathCheckOffset = 2,          -- meters
        pathAlignmentAngleLimit = 10,        -- degrees
        pathAlignmentDistanceLimit = 200     -- meters

    },
    route = {
        routeStartDistanceLimit = 10,    -- meters
        autoShutdownFloorDistance = 5,   -- meters
        yawAlignmentThrustLimiter = 3,   -- degrees
        pitchAlignmentThrustLimiter = 5, -- degrees
        rollAlignmentThrustLimiter = 5,  -- degrees
        gateControlDistance = 5          -- meters
    },
    widgets = {
        showOnStart = false
    }
}

return constants
