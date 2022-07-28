local n = {
    library = require("du-libs:abstraction/Library")(),
    vehicle = require("du-libs:abstraction/Vehicle")(),
    calc = require("du-libs:util/Calc"),
    brakes = require("flight/Brakes")(),
    log = require("du-libs:debug/Log")(),
    utils = require("cpml/utils"),
    universe = require("du-libs:universe/Universe")(),
    checks = require("du-libs:debug/Checks"),
    visual = require("du-libs:debug/Visual")(),
    Vec3 = require("cpml/vec3")
}

return n