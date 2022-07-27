-- Make states globally available so they can all reference each other without creating require-loops
if not FLIGHT_STATES_INCLUDED then
    FLIGHT_STATES_INCLUDED = true
    ApproachWaypoint = require("flight/state/ApproachWaypoint")
    Hold = require("flight/state/Hold")
    Idle = require("flight/state/Idle")
    Travel = require("flight/state/Travel")
    ReturnToPath = require("flight/state/ReturnToPath")
end