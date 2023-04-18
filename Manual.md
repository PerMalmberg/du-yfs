# Yoarii's Flight system

Please read the entire manual before attempting to perform an installation, there are important information throughout that will impact the choices you make.

## Overview

The goal of this project was initially to write a flight system capable of working as what is known as a shaft-less space elevator. i.e. vertical movement around a predefined path. The chosen design does however allow for more than just that and is capable of movement in any direction, within limits of the construct it operates. The original target of only vertical movement along the gravity vector was thus surpassed and it is possible to go in a straight line at an angle from the vertical gravity vector. Further, it also allows you to do up-and-over maneuvers where the construct parks itself on a space platform from whichever direction you desire.

### Required elements (for Do-It-Yourself kits)

* A data bank named "Routes"
* A telemeter named "FloorDetector", pointing downwards
* Optional data bank named "Settings"
* Screen (optional, but strongly recommended)
* Atmospheric engines are required in all direction, except in the upward direction as gravity does the job.
* In space, you need engines in all directions.
* Aim for 3g for upward lift when fully loaded.

### Routes

Routes is an important concept for this flight system as they are what guides the construct between positions. A route consists of two or more waypoints, a beginning, an end, and any number of waypoints in-between. A waypoint specifies a position in the world. When added to a route a waypoint is associated with other attributes, such as alignment direction and maximum speed. A route can also contain anonymous waypoints; these exists only in one route and can't be reused. Routes are run beginning to end, unless started in reverse.

### Waypoint alignment

The construct will align towards the next point in the route (see setting `yawAlignmentThrustLimiter`), unless that point has a locked alignment direction, in which case the construct will keep that direction while approaching the waypoint. The construct will also automatically lock and hold the direction if the next target point is nearly straight up or down from its current position, when issued a `move` command.

### Enclosures

If you intend to build an enclosure for the construct remember that physics in Dual Universe creates a hit box around constructs in the shape of a box, not the visual contours. As such your enclosure must be able to fit a box the size of the extreme distances of the construct on all three axes.

### Floors for parking; ground and space

Due to Dual Universe's slightly wonky physics, when creating floors for any dynamic construct, ensure that the floor fully encompasses the dynamic construct and it does NOT cross core boundaries or it might clip through and fall, or worse, explode.

## Installation as an elevator (ground to space)

### Aligning the elevator to your ground construct

To get a near-perfect alignment of the elevator to your ground construct, follow these steps.

1. Place a Programming Board on the construct that will contain the dock/cradle/landing pad of the elevator.
2. Connect a screen to the programming board.
3. Select the direction you want to align to and paste one of the four code snippets below into `unit -> start`, whichever is appropriate.

    * Align to forward vector
      ```lua
      local Vec3 = require("cpml/vec3")
      local v = Vec3(construct.getWorldOrientationForward())
      local s = string.format("align-to-vector -x %0.14f -y %0.14f -z %0.14f", v.x, v.y, v.z)
      slot1.setCenteredText(s)
      unit.exit()
      ```
    * Align to backwards vector
      ```lua
      local Vec3 = require("cpml/vec3")
      local v = -Vec3(construct.getWorldOrientationForward())
      local s = string.format("align-to-vector -x %0.14f -y %0.14f -z %0.14f", v.x, v.y, v.z)
      slot1.setCenteredText(s)
      unit.exit()
      ```
    * Align to right vector
      ```lua
      local Vec3 = require("cpml/vec3")
      local v = Vec3(construct.getWorldOrientationRight())
      local s = string.format("align-to-vector -x %0.14f -y %0.14f -z %0.14f", v.x, v.y, v.z)
      slot1.setCenteredText(s)
      unit.exit()
      ```
    * Align to left vector
      ```lua
      local Vec3 = require("cpml/vec3")
      local v = -Vec3(construct.getWorldOrientationRight())
      local s = string.format("align-to-vector -x %0.14f -y %0.14f -z %0.14f", v.x, v.y, v.z)
      slot1.setCenteredText(s)
      unit.exit()
      ```

4. Start the Programming Board and copy the command from the screen (CTRL-L to to open editor while pointing to the screen).
   * The command is the part in the `text = ....` line of the screen code. Do not copy the quotation marks.
5. Start the elevator, enter manual control mode and raise it up slightly using the `move` command. Manual mode is needed to prevent it to shutdown automatically.
6. Paste the command into Lua-chat and press enter to perform the alignment.
   * Showing the widgets (`show-widgets 1`) and looking in the "Rotation" widget, under "Axis/Yaw", at the _offset_ value will show 0 when it is aligned.
7. Once aligned, either hold C or use the `move` command to set it down again.
8. Turn off the elevator.

### Creating the route

1. Decide on what distance above (_not_ height above sea level) you want the route to stop at.
2. Decide on a name for the route. You can use spaces in it, but you must surround it with single quotes, like so: `'a name'`. Double quotes do currently not work due to a bug in DU. Keep the name at 14 characters or less so it fits on the screen.
3. Activate the elevator.
4. In Lua chat, type:
   `create-vertical-route 'route name' -distance 12345`, replacing values as appropriate.
   * If this isn't your first elevator, add the `-x`, `-y`, and `-z` arguments to the `create-vertical-route` command you get using the instructions in the "Travel vector for additional elevators" section.

The screen will now show the name of your route with two buttons, one for the beginning (ground) and end (space). Simply clicking these buttons will make the elevator move to those respective locations.

### Travel vector for additional elevators

To ensure that elevators end up at the same relative distances in space as they have on the ground, you need to make them use the same travel direction. To do so, follow these instructions:

1. Select one elevator as the reference elevator.
2. Activate the elevator
3. Type the following command into Lua chat:
   > `print-vertical-up`

   This will print something like this:
   > `[I] -x 0.123 -y 0.456 -z 0.789`

4. Copy this from the chat (right click on the Lua chat tab to access menu) and paste it into your favorite text editor and extract everything after the `[I]`, you'll find it at the very end of the text.

## Space core placement

When placing the space core/construct, using the snapping mode on the elevator can make it much easier to align it correctly. Just keep in mind where the parking spot is meant to be etc.

Hint: To activate snapping mode, point into empty space, then click middle mouse button, then left click on the elevator to select it as a reference construct and move the new core/construct using normal adjustment keys. If you're doing it alone, the ECU must be holding the elevator in place, you can't actively run the remote controller while deploying a core/construct.

## Key bindings

| Key         | Description                                                      |
| ----------- | ---------------------------------------------------------------- |
| Alt-Shift-9 | (Un)locks player / enters/exists manual control (WSAD etc.) mode |


## Manual Controls (when user is locked in place)

| Key                | Description                 |
| ------------------ | --------------------------- |
| A                  | Turn left                   |
| S                  | Move backwards              |
| W                  | Move forward                |
| D                  | Turn right                  |
| C                  | Move down                   |
| Space              | Move  up                    |
| Alt-A              | Strafe left                 |
| Alt-D              | Strafe right                |
| Mouse scroll wheel | Increase/decrease max speed |

> Note: Manual control of heavy constructs are much less accurate (especially during vertical movements). Don't expect the same maneuverability as a tiny 1.5t construct.

## LUA console commands

| Command                   | Parameters/options         | Unit    | Optional | Description                                                                                                                                                                                          |
| ------------------------- | -------------------------- | ------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| move                      |                            |         |          | Initiates a movement relative to the current position                                                                                                                                                |
|                           | -f                         | meter   | Y        | Forward distance; negate to move backwards.                                                                                                                                                          |
|                           | -u                         | meter   | Y        | Upward distance; negate to move downwards.                                                                                                                                                           |
|                           | -r                         | meter   | Y        | Rightward distance; negate to move leftwards.                                                                                                                                                        |
|                           | -maxspeed                  | km/h    | Y        | Maximum approach speed                                                                                                                                                                               |
|                           | -lockdir                   | boolean | Y        | if true, locks the direction during the approach to that which the construct had when the command was issued.                                                                                        |
|                           | -margin                    | meter   | Y        | The maximum distance from the destination the construct may be for the destination to be considered reached.                                                                                         |
| goto                      | waypoint or ::pos{} string |         |          | Moves to the given point                                                                                                                                                                             |
|                           | -maxspeed                  | km/h    | Y        | See &lt;move&gt;                                                                                                                                                                                     |
|                           | -lockdir                   |         | Y        | See &lt;move&gt;                                                                                                                                                                                     |
|                           | -margin                    | meter   | Y        | See &lt;move&gt;                                                                                                                                                                                     |
|                           | -offset                    | meter   | Y        | If specified, the distance will be shortened by this amount, i.e. stop before reaching the position. Good for approaching unknown locations.<br/>Negative offsets means the other side of the point. |
| print-pos                 |                            |         |          | Prints the current position and current alignment point                                                                                                                                              |
| align-to                  | waypoint or ::pos{} string |         |          | Aligns to the given point or named waypoint                                                                                                                                                          |
| align-to-vector           |                            |         |          | Aligns to the given point, as given by a 3D-vector. See section "Aligning the elevator to your ground construct"                                                                                     |
|                           | -x                         | number  | N        | X-component of the vector                                                                                                                                                                            |
|                           | -y                         | number  | N        | X-component of the vector                                                                                                                                                                            |
|                           | -z                         | number  | N        | X-component of the vector                                                                                                                                                                            |
| hold                      |                            |         |          | Stops and returns to the position at the time of execution, then holds.                                                                                                                              |
| idle                      |                            |         |          | Puts the system into idle mode, engines are off.                                                                                                                                                     |
| turn                      | angle                      | degrees | N        | Turns the construct the specified number of degrees around the Z-axis (up)                                                                                                                           |
| strafe                    | distance                   | meter   | N        | Initiates a strafing move with locked direction.                                                                                                                                                     |
| route-list                |                            |         |          | Lists the currently available routes                                                                                                                                                                 |
| route-edit                | name of route              |         | N        | Opens a route for editing                                                                                                                                                                            |
| route-create              | name of route              |         | N        | Creates a new route for editing                                                                                                                                                                      |
| route-save                |                            |         |          | Saves the currently open route                                                                                                                                                                       |
| route-activate            | name of route              |         | N        | Activates the named route and start the flight.                                                                                                                                                      |
|                           | -reverse                   | boolean | Y        | Runs the route in reverse, i.e. the last point becomes the first.                                                                                                                                    |
| route-reverse             |                            |         |          | Reverses the currently open route                                                                                                                                                                    |
| route-delete              | name of route              |         | N        | Deletes the named route                                                                                                                                                                              |
| route-delete-pos          | index of waypoint          | number  | N        | Removes the point at index from the route.                                                                                                                                                           |
| route-move-pos            |                            |         |          | Moves a point from one index to another                                                                                                                                                              |
|                           | -from                      | number  |          | The index to move from                                                                                                                                                                               |
|                           | -to                        |         |          | The index to move to. Positions at and after the position are shifted forward.                                                                                                                       |
| route-move-pos-forward    | position index, 1..n       | number  | N        | Moves the position at the given index one step forward.                                                                                                                                              |
| route-move-pos-back       | position index, 1..n       | number  | N        | Moves the position at the given index one step backward.                                                                                                                                             |
| route-add-current-pos     |                            |         |          | Adds the current position to the current route                                                                                                                                                       |
|                           | -maxspeed                  | km/h    | Y        | See &lt;move&gt;                                                                                                                                                                                     |
|                           | -lockdir                   | boolean | Y        | See &lt;move&gt;                                                                                                                                                                                     |
|                           | -margin                    | meter   | Y        | See &lt;move&gt;                                                                                                                                                                                     |
| route-add-named-pos       |                            |         |          |                                                                                                                                                                                                      |
|                           | name of waypoint           |         |          | Adds a named waypoint to the route                                                                                                                                                                   |
|                           | -maxspeed                  | km/h    | Y        | See &lt;move&gt;                                                                                                                                                                                     |
|                           | -lockdir                   |         | Y        | See &lt;move&gt;                                                                                                                                                                                     |
|                           | -margin                    | meter   | Y        | See &lt;move&gt;                                                                                                                                                                                     |
| route-set-all-margins     |                            | meter   | N        | Sets margin on all points in the route to the provided value                                                                                                                                         |
| route-set-all-max-speeds  |                            | km/h    | N        | Sets max speed on all points in the route to get provided value                                                                                                                                      |
| route-print               |                            |         |          | Prints the current route to the console                                                                                                                                                              |
| pos-create-along-gravity  | name of waypoint           |         |          | Creates a waypoint relative to the constructs position along the gravity vector.                                                                                                                     |
|                           | -u                         | meter   | N        | Upward distance; negate to place point downwards the source of gravity                                                                                                                               |
| pos-create-relative       | name of waypoint           |         |          | Creates a waypoint relative to the construct and its current orientation.                                                                                                                            |
|                           | -f                         | meter   | Y        | Forward distance; negate to move backwards.                                                                                                                                                          |
|                           | -u                         | meter   | Y        | Upward distance; negate to move downwards.                                                                                                                                                           |
|                           | -r                         | meter   | Y        | Rightward distance; negate to move leftwards.                                                                                                                                                        |
| pos-print-relative        |                            |         |          | Prints the position relative to the construct and its current orientation.                                                                                                                           |
|                           | -f                         | meter   | Y        | Forward distance; negate to move backwards.                                                                                                                                                          |
|                           | -u                         | meter   | Y        | Upward distance; negate to move downwards.                                                                                                                                                           |
|                           | -r                         | meter   | Y        | Rightward distance; negate to move leftwards.                                                                                                                                                        |
| pos-save-current-as       | name of waypoint           |         | N        | Save the current position as a named waypoint for later use in a route                                                                                                                               |
| pos-save-as               | name of waypoint           |         | N        | Saves the provided position as a named waypoint for later use in a route                                                                                                                             |
|                           | -pos                       | ::pos{} | N        | The position string to save as the given name                                                                                                                                                        |
| pos-list                  |                            |         |          | Lists the saved positions                                                                                                                                                                            |
| pos-delete                |                            |         |          | Deletes a waypoint.                                                                                                                                                                                  |
|                           | name of waypoint           | string  | N        | The waypoint to delete.                                                                                                                                                                              |
| create-vertical-route     | name of route              |         |          | Creates a route by the given name from current position to a point above (or below) at the given distance using the given values for the up-vector.                                                  |
|                           | -distance                  | number  | N        | The distance of the point above or below (when negative)                                                                                                                                             |
|                           | -followGravInAtmo          |         | Y        | If specified an extra point will be added so that the part of the path that is in atmosphere will follow the gravity vector, regardless of the specified custom vector.                              |
|                           | -extraPointMargin          | number  | N        | Specifies the margin used for the extra point, default 5 m.                                                                                                                                          |
|                           | -x                         | number  | N        | Specifies the X-value of the direction vector (see 'Travel vector for additional elevators').                                                                                                        |
|                           | -y                         | number  | N        | Specifies the Y-value of the direction vector (see 'Travel vector for additional elevators').                                                                                                        |
|                           | -z                         | number  | N        | Specifies the Z-value of the direction vector (see 'Travel vector for additional elevators').                                                                                                        |
| print-vertical-up         |                            |         |          | Prints the vertical up-vector at the current location. Used to get values for use with `create-vertical-route`.                                                                                      |
| set                       |                            |         |          | Sets the specified setting to the specified value                                                                                                                                                    |
|                           | -engineWarmup              | seconds | Y        | Sets the engine warmup time (T50). Set this to that of the engine with longes warmup.                                                                                                                |
|                           | -containerProficiency      | integer | Y        | Sets the container proficiency talent level, 1-5                                                                                                                                                     |
|                           | -fuelTankOptimization      | integer | Y        | Sets the fuel tank optimization talent level, 1-5                                                                                                                                                    |
|                           | -atmoFuelTankHandling      | integer | Y        | Sets the atmospheric fuel tank handling talent level, 1-5                                                                                                                                            |
|                           | -spaceFuelTankHandling     | integer | Y        | Sets the space fuel tank handling talent level, 1-5                                                                                                                                                  |
|                           | -rocketFuelTankHandling    | integer | Y        | Sets the rocket fuel tank handling talent level, 1-5                                                                                                                                                 |
|                           | -autoShutdownFloorDistance | number  | Y        | Sets the distance at which the system shuts down while in Hold-state, as measured by the 'FloorDetector' telemeter                                                                                   |
|                           | -yawAlignmentThrustLimiter | number  | Y        | Sets the alignment limit angle which yaw must be within before accelerating to the next waypoint.                                                                                                    |
|                           | -showWidgetsOnStart        | boolean | Y        | If true, diagnostics widgets are shown on start up                                                                                                                                                   |
|                           | -routeStartDistanceLimit   | number  | Y        | Sets the maximum allowed activation distance between the construct and the closest point of a route                                                                                                  |
|                           | -throttleStep              | number  | Y        | Sets the step size of the throttle in manual control mode in percent, default 10                                                                                                                     |
|                           | -manualControlOnStartup    | boolean | Y        | If true, manual mode is activated on startup.                                                                                                                                                        |
|                           | -turnAngle                 | degrees | Y        | Sets the turn angle per key press for the manual control mode.                                                                                                                                       |
|                           | -minimumPathCheckOffset    | meter   | Y        | Sets the minimum allowed offset from the path during travel at which the construct will stop to and return to the path.                                                                              |
| get                       | See `set`                  |         | Y        | Prints the setting set with the `set` command, don't add the leading `-`.                                                                                                                            |
| get-all                   |                            |         |          | Prints all current settings                                                                                                                                                                          |
| reset-settings            |                            |         |          | Resets all settings to their defaults.                                                                                                                                                               |
| set-full-container-boosts |                            |         |          | Sets all related talents for containers, atmospheric, space and rocket fuel tanks to level 5                                                                                                         |
| show-widgets              |                            | boolean | Y        | Show/hides widgets with diagnostic info                                                                                                                                                              |


## Mass Overload

Each construct has a max cargo mass it is rated for. If you load the construct with more then one or more of the following may happen:

| Event                                                                      | Possible reasons                                                                                                      |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| When taking off from planet, it will start, brake, start repeatedly.       | Too little brake force to counter gravity for the current mass, which causes the math to say max speed of 0 km/h.     |
| When reaching higher atmosphere it may slow down, stop, and start falling. | Engines not being powerful enough, and/or the thin atmosphere causing too much reduction in power, or too heavy load. |

Should you end up in these situations, it is easiest to just disable the controller (and the ECU), and let it fall back down a bit then activate it again. It will then attempt to hold the position it was at when it was started, i.e. brake and activate engines to counter the fall. You can repeat this until you're at an height the engines work again. Having said that, an overloaded ship is still overloaded and bad things are likely to happen.

## Accuracy

The aim is 0.1m accuracy and this is also the default for the all movements. However, depending on various factors such as engine choice, mass (and thus acceleration), the construct may go off the path slightly. There is a failsafe that triggers if the nearest point on the path is more than 1m (setting `minimumPathCheckOffset`) away (or as defined by the next waypoints), in which case the construct will brake and return to the point at which it went off the path before continuing the route. If you want to override this behavior, you can reactivate the route again which will make the construct move to the closest point on the path from where where it is when you activate the route.

You may also increase the margin on specific waypoints to allow a bit more wiggle room during travel, this may be especially useful on waypoints towards which the acceleration/speed is high or the path is diagonal relative to the gravity vector. Alternatively, you can set a maximum speed to reduce acceleration duration and speed.

### A note on non gravity-aligned atmospheric accent/decent and angled flight paths

While it is possible to make routes that are not gravity aligned work, they may be somewhat unreliable. These are the main reasons:

* Atmospheric brakes

  > Quote from NQ-support:
  > The speed is projected on the horizontal plane of the construct. And we add a brake force in that plane in the opposite direction of that projected speed, which induces a vertical force when the ship has a pitch.

  It is this horizontal force that causes the construct to be pushed off the path. The easiest way to work around this is to ensure that the entry to the planet is aligned with the gravity vector by adding an extra point in the route in space directly above the point inside the atmosphere (see `pos-create-along-gravity`). The downside is that this will be a position the construct has to stop at, which prolongs the travel time and increases fuel consumption due to extra acceleration.

* Strong acceleration

  Sideways engines are generally weaker than the main downward pointing engines so when accelerating, the weaker ones may have difficulties to keep the construct on the path.

## Emergency Controller Unit

When running on an ECU, the script only do to things:
* Attempts to hold the position it has when activated
* Detect a floor, and if detected it shuts down.

The requirements for linking are the same as for when running on a controller.