# Todo

* Route not loading speed?
* Add unit tests for route point
* Add unit tests for point options
* Add unit tests for route
* Add unit tests for route controller
* All classes - use new class template
* Adjustment read zero distance when off from path sometimes. Not always active?!?

# Controls

| Key   | Description             |
|-------|-------------------------|
| A     | Turn left               |
| S     | Move one step backwards |
| W     | Move one step forward   |
| D     | Turn right              |
| C     | Move one step down      |
| Space | Move one step up        |
| ALT-A | Strafe left             |
| ALT-D | Strafe right            |

# LUA console commands

| Command               | Parameters/options | Unit    | Optional | Description                                                                                                   |
|-----------------------|--------------------|---------|----------|---------------------------------------------------------------------------------------------------------------|
| step                  | distance           | meter   | N        | Sets the default step ASWD movement and other commands                                                        |
| speed                 | speed              | kph     | N        | Sets the max default speed for ASWD movement                                                                  |
| move                  |                    |         |          | Initiates a movement relative to the current position                                                         |
|                       | -f                 | meter   | Y        | Forward distance; negate to move backwards.                                                                   |
|                       | -u                 | meter   | Y        | Upward distance; negate to move downwards.                                                                    |
|                       | -r                 | meter   | Y        | Rightward distance; negate to move leftwards.                                                                 |
|                       | -maxspeed          | kph     | Y        | Maximum approach speed                                                                                        |
|                       | -precision         | boolean | Y        | if true, the approach will use precision mode.Recommended for 'elevator' movement.                            |
|                       | -lockdir           | boolean | Y        | if true, locks the direction during the approach to that which the construct had when the command was issued. |
|                       | -margin            | meter   | Y        | The maximum distance from the destination the construct may be for the destination to be considered reached.  |
| turn                  | angle              | degrees | N        | Turns the construct the specified number of degrees around the Z-axis (up)                                    |
| strafe                | distance           | meter   | N        | Initiates a strafing move with locked direction.                                                              |
| route-list            |                    |         |          | Lists the currently available routes                                                                          |
| route-load            | name of route      |         | N        | Loads a route for editing                                                                                     |
| route-create          | name of route      |         | N        | Creates a new route for editing                                                                               |
| route-save            |                    |         |          | Saves the currently open route                                                                                |
| route-activate        | name of route      |         | N        | Activates the named route and start the flight.                                                               |
| route-delete          | name of route      |         | N        | Deletes the named route                                                                                       |
| route-add-current-pos |                    |         |          | Adds the current position to the current route                                                                |
|                       | -maxspeed          | kph     | Y        | Maximum approach speed                                                                                        |
|                       | -precision         | boolean | Y        | if true, the approach will use precision mode.Recommended for 'elevator' movement.                            |
|                       | -lockdir           | boolean | Y        | if true, locks the direction during the approach to that which the construct had when the command was issued. |
|                       | -margin            | meter   | Y        | The maximum distance from the destination the construct may be for the destination to be considered reached.  |
| route-add-named-pos   |                    |         |          |                                                                                                               |
|                       | name of waypoint   |         |          | Adds a named waypoint to the route                                                                            |
|                       | -maxspeed          | kph     | Y        | Maximum approach speed                                                                                        |
|                       | -precision         | boolean | Y        | if true, the approach will use precision mode.Recommended for 'elevator' movement.                            |
|                       | -lockdir           | boolean | Y        | if true, locks the direction during the approach to that which the construct had when the command was issued. |
|                       | -margin            | meter   | Y        | The maximum distance from the destination the construct may be for the destination to be considered reached.  |
| route-dump            |                    |         |          | Dumps the current route to the console                                                                        |
| save-position-as      | name of waypoint   |         | N        | Save the current position as a named waypoint for later use in a route                                        |
| set                   |                    |         |          | Sets the specified setting to the specified value                                                             |
|                       | -engineWarmup      | seconds | Y        | Sets the engine warmup time (T50). Set this to that of the engine with longes warmup.                         |
| get                   | <same as 'set'>    |         |          | Displays the value of the specified value                                                                     |

# Flight

```mermaid
flowchart TD
  Idle-->Travel
  ApprochingLast{last waypoint}
  ApproachWaypoint -- out of alignment --> ReturnToPath
  ApproachWaypoint -- dist < brakeDist && dist > 100 && time > 1s --> Travel
  ApproachWaypoint -- waypoint reached --> ApprochingLast
  ApprochingLast -- Yes --> Hold
  ApprochingLast -- No --> Travel
  ReturnToPath -- distance < margin --> Travel
  Travel -- need to brake -->ApproachWaypoint
  Travel -- out of alignment --> ReturnToPath
  Hold -- too far --> ApproachWaypoint
 ```

# Cross and dot

Right hand rule for cross product:

* Point right flat hand in direction of first arrow
* Curl fingers in direction of second.
* Thumb now point in direction of the resulting third arrow.

  a.b = 0 when vectors are orthogonal.
  a.b = 1 when vectors are parallel.
  axb = 0 when vectors are parallel.