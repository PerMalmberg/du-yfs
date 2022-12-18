# Todo

* Stuck on pad on activation - wants to move to first point?
* Use PID for adjustment
* Jitter on small construct when holding position.
* Overshoot upwards? Small construct 1000m

* More natural manual control
* Fix overshoot when turning

* When activating a route, ensure that construct is less than 1m from first point.
  * If the reveresed route makes the construct within the limit, run the route reveresed.
  * Button to set waypoint to closes endpoint

# FAQ

- Q: For up-and-over parking, how much above the floor of the space core must the construct enter?
- A: 7m, high enough that it is not caught by the gravity well of the space construct.

- Q: It accelerates, then brakes when taking off
- A: Too heavy load, brake calculations say max 0 km/h.

## Screens

### Take me there
- List of routes
  - Favorites listed first
- Select route, display info.
- Separate button to start route.
- Emergency stop button

### Travel screen
- Emergency stop button - hold position / zero speed limit?
- Leg x of y
- Distance to next point
- Distance to end point (via route)
- Current speed
- Target speed
- Fuel
- Mass
  - Cargo
  - Total

### Control screen
- Step up/down
- Angle + up/down buttons
- Speed up/down
- Display current values

### Edit route

- Button
  - Update options for point; checkboxes for options
  - Save current pos


* -- https://github.com/Dimencia/Archaegeo-Orbital-Hud/blob/7414fa08c50605936bd6a1dc3abfe503dd65a10c/src/requires/apclass.lua#L2755

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
| route-edit            | name of route      |         | N        | Opens a route for editing                                                                                     |
| route-create          | name of route      |         | N        | Creates a new route for editing                                                                               |
| route-save            |                    |         |          | Saves the currently open route                                                                                |
| route-activate        | name of route      |         | N        | Activates the named route and start the flight.                                                               |
|                       | -reverse           | booean  | Y        | Runs the route in reverse, i.e. the last point becomes the first.                                             |
| route-reverse         |                    |         |          | Reverses the currently open route                                                                             |
| route-delete          | name of route      |         | N        | Deletes the named route                                                                                       |
| route-move-pos        |                    |         |          | Moves a point from one index to another                                                                       |
|                       | -from              | number  |          |  The index to move from                                                                                       |
|                       | -to                |         |          |  The index to move to. Positons at and after the position are shifted forward.                                |
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
| route-print           |                    |         |          | Prints the current route to the console                                                                       |
| pos-create-along-gravity   | name of waypoint   |         |          | Creates a waypoint relative to the constructs position along the gravity vector.                         |
|                       | -u                 | meter   | N        | Upward distance; negate to place point downwards the source of gravity                                        |
| pos-save-as           | name of waypoint   |         | N        | Save the current position as a named waypoint for later use in a route                                        |
| pos-list              |                    |         |          | Lists the saved positions                                                                                     |
| pos-delete            |                    |         |          | Deletes a waypoint.                                                                                           |
|                       | name of waypoint   | string  | N        | The waypoint to delete.                                                                                       |
| set                   |                    |         |          | Sets the specified setting to the specified value                                                             |
|                       | -engineWarmup      | seconds | Y        | Sets the engine warmup time (T50). Set this to that of the engine with longes warmup.                         |
| get                   | <same as 'set'>    |         |          | Displays the value of the specified value                                                                     |
| alias                 | name of alias      |         |          | Creates an alias of a command                                                                                 |
|                       | command to execute | string  | N        | The command to execute as a string enclosed in "", e.g. "route-activate myroute -reverse"                     |

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