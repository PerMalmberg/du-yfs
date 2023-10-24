local s = {
    constants     = require("YFSConstants"),
    log           = require("debug/Log").Instance(),
    strUtil       = require("util/StringUtil"),
    commandLine   = require("commandline/CommandLine").Instance(),
    input         = require("input/Input").Instance(),
    pub           = require("util/PubSub").Instance(),
    calc          = require("util/Calc"),
    brakes        = require("flight/Brakes").Instance(),
    universe      = require("universe/Universe").Instance(),
    keys          = require("input/Keys"),
    gateCtrl      = require("controller/GateControl").Instance(),
    radar         = require("element/Radar").Instance(),
    floorDetector = require("controller/FloorDetector").Instance(),
    timer         = require("system/Timer").Instance()
}

return s
