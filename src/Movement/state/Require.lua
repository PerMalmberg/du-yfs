-- Make states globally available so they can all reference each other without creating require-loops
Idle = require("movement/state/Idle")
ApproachWaypoint = require("movement/state/ApproachWaypoint")
Travel = require("movement/state/Travel")
Decelerate = require("movement/state/Decelerate")
Hold = require("Movement/state/Hold")