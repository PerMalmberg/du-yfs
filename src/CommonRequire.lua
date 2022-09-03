local n = {
    library = require("abstraction/Library")(),
    vehicle = require("abstraction/Vehicle"):New(),
    calc = require("util/Calc"),
    brakes = require("flight/Brakes")(),
    log = require("debug/Log")(),
    utils = require("cpml/utils"),
    universe = require("universe/Universe")(),
    checks = require("debug/Checks"),
    visual = require("debug/Visual")(),
    engine = require("abstraction/Engine")(),
    Vec3 = require("cpml/vec3")
}

return n