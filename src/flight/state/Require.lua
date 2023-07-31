-- Make states globally available so they can all reference each other without creating require-loops
if not FLIGHT_STATES_INCLUDED then
    FLIGHT_STATES_INCLUDED = true
    Hold = require("flight/state/Hold") ---@type Hold
    Idle = require("flight/state/Idle") ---@type Idle
    Travel = require("flight/state/Travel") ---@type Travel
    ReturnToPath = require("flight/state/ReturnToPath") ---@type ReturnToPath
    OpenGates = require("flight/state/OpenGates") ---@type OpenGates
end
