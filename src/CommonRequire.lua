local n = {
    vehicle = require("abstraction/Vehicle").New(),
    calc = require("util/Calc"),
    log = require("debug/Log")(),
    utils = require("cpml/utils"),
    universe = require("universe/Universe").Instance(),
    checks = require("debug/Checks"),
    visual = require("debug/Visual")(),
    engine = require("abstraction/Engine").Instance(),
    Vec3 = require("math/Vec3")
}

return n
