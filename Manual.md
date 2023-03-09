# Yoarii's Flight system

Please read the entire manual before attempting to perform an installation, there are important information throughout that will impact the choices you make.

## Overview

The goal of this project was initially to write a flight system capable of working as what is known as a shaft-less space elevator. i.e. vertical movement around a predefined path. The chosen design does however allow for more than just that and is capable of movement in any direction, within limits of the construct it operates. The original target of only vertical movement along the gravity vector was thus surpassed and it is possible to go in a straight line at an angle from the vertical gravity vector. Further, it also allows you to do up-and-over maneuvers where the construct parks itself on a space platform from whichever direction you desire.

### Required elements

* A data bank named "Routes"
* A telemeter named "FloorDetector", pointing downwards
* Optional data bank named "Settings"
* Screen (optional, but strongly recommended)

### Routes

Routes is an important concept for this flight system as they are what guides the construct between positions. A route consists of two or more waypoints, a beginning, an end, and any number of waypoints in-between. A waypoint specifies a position in the world. When added to a route a waypoint is associated with other attributes, such as alignment direction and maximum speed. A route can also contain anonymous waypoints; these exists only in one route and can't be reused. Routes are run beginning to end, unless started in reverse.

### Waypoint alignment

The construct will align towards the next point in the route (see setting `yawAlignmentThrustLimiter`), unless that point has a locked alignment direction, in which case the construct will keep that direction while approaching the waypoint. The construct will also automatically lock and hold the direction if the next target point is nearly straight up or down from its current position, when issued a `move` command.

### Enclosures

If you intend to build an enclosure for the construct remember that physics in Dual Universe creates a hit box around constructs in the shape of a box, not the visual contours. As such yor enclosure must be able to fit a box the size of the extreme distances of the construct on all three axes.

### Floors for parking; ground and space

Due to Dual Universe's slightly wonky physics, when creating floors for any dynamic construct, ensure that the floor fully encompasses the dynamic construct or it might clip through and fall, or worse, explode.

## Installation as an elevator (ground to space)

First, select which type of installation you want:

* Gravity-aligned - this is the standard option where the the construct follows the gravity vector between two points. It is easy to setup but the drawback is that an installations with multiple elevators results in a wider spread of them in space, compared to the ground location due to the gravity vector pointing in a different direction at each location on the ground (Imagine an arrow from the center of the planet through the ground location; when you move so does it.).

* Vertical - this option creates a two-part route with the atmospheric part being gravity aligned and the space part being vertically aligned with the construct the elevator parks on at the ground. This option requires a few extra steps to setup but allows you to easily park multiple elevators close to each other
both at the ground location as well as in space. The drawback is the stop-and-go at the extra midpoint needed to realign which slightly increases travel time.

No matter which option you chose you can always adjust the routes at a later date. There is also the option to use gravity-aligned in combination with extra waypoints at the end of the route in space to maneuver the elevator into its target destination.

### Gravity-aligned setup

1. Place the elevator at the ground location you want it at and make sure that it is facing the desired direction. It is recommended that you use a voxel floor instead of the ground.
2. Activate the remote controller
3. Ensure that location and direction is still what you want them to be. If not you can do fine adjustments using the available movement commands.
4. Replacing `<name>` and `<distance>` with the the actual name and distance (in meter), execute the following in Lua chat:

   `create-gravity-route <name> -distance <distance>`

    Example: `create-gravity-route Space -distance 100000`

    This creates a route named "Space" with an endpoint 100km above, along the gravity vector.

The screen will now show the name of your route with two buttons, one for the beginning (ground) and end (space). simply clicking these buttons will make the elevator move to those respective locations.

### Vertical setup

1. Ensure that the ground construct you want to use as the vertical reference is where you want it to be.
2. Place a Programming Board on the construct that will determine what constitutes as "vertically up".
3. Paste this code in `unit -> start`
```lua
local Vec3 = require("cpml/vec3")
local up = Vec3(construct.getWorldOrientationUp())
system.print("Use these values as the vertical vector: ")
system.print("X: " .. up.x)
system.print("Y: " .. up.y)
system.print("Z: " .. up.z)
unit.exit()
```
4. Start the Programming Board and copy the X, Y and Z values. You can right-click on the chat tab to copy the contents of the chat window in Json-format. Tools like visual Studio can easily format this to make it more readable.
5. Execute the following command in Lua-chat on the construct you want to create the vertical route for
`create-vertical-route <name>; -distance <nnn>; -vertX <X>; -vertY <Y>; -vertZ <Z>`, replacing the respective placeholders with the actual values.

   Example: `create-vertical-route test -distance 100000 -vertX -0.60683256387711 -vertY 0.2140174806118 -vertZ 0.76547425985336`

By default this will create a route with an extra path-correction point outside atmosphere where the construct will stop both on the way in and out of atmosphere. If you disable this (using `-followGravInAtmo false`) you should probably increase the margin of the waypoints in the route from the default 0.1m to something larger, depending on the angle of the path toward the gravity vector.

#### The reason the up-vector of the construct itself is not used

Even though a parked construct appears to be sitting perfectly flat onto another, this is seldom actually the case. As such, assuming the up-vector of the elevator is the same as that of the construct on which the elevator is parked on results in different results between different positions as well as different park attempts. With distances of 100km, even a tiny difference results in large differences at the far end.

## Space core placement

When placing the space core/construct, using the snapping mode on the elevator can make it much easier to align it correctly. Just keep in mind where the parking spot is meant to be etc.

Hint: To activate snapping mode, point into empty space, then click middle mouse button, then left click on the elevator to select it as a reference construct and move the new core/construct using normal adjustment keys. If you're doing it alone, the ECU must be holding the elevator in place, you can't actively run the remote controller while deploying a core/construct.

## Shortcuts

| Key         | Description      |
| ----------- | ---------------- |
| Alt-Shift-9 | (Un)locks player |


## Controls (when user is locked in place)

| Key   | Description                        |
| ----- | ---------------------------------- |
| A     | Turn left                          |
| S     | Move one step backwards (and turn) |
| W     | Move one step forward              |
| D     | Turn right                         |
| C     | Move one step down                 |
| Space | Move one step up                   |
| Alt-A | Strafe left                        |
| Alt-D | Strafe right                       |

## LUA console commands

| Command                   | Parameters/options         | Unit    | Optional | Description                                                                                                                                         |
| ------------------------- | -------------------------- | ------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| step                      | distance                   | meter   | N        | Sets the default step ASWD movement and other commands                                                                                              |
| speed                     | speed                      | kph     | N        | Sets the max default speed for ASWD movement                                                                                                        |
| move                      |                            |         |          | Initiates a movement relative to the current position                                                                                               |
|                           | -f                         | meter   | Y        | Forward distance; negate to move backwards.                                                                                                         |
|                           | -u                         | meter   | Y        | Upward distance; negate to move downwards.                                                                                                          |
|                           | -r                         | meter   | Y        | Rightward distance; negate to move leftwards.                                                                                                       |
|                           | -maxspeed                  | kph     | Y        | Maximum approach speed                                                                                                                              |
|                           | -precision                 |         | Y        | if true, the approach will use precision mode, i.e. separated thrust and adjustment calculations. Automatically applied for near-vertical movements |
|                           | -lockdir                   | boolean | Y        | if true, locks the direction during the approach to that which the construct had when the command was issued.                                       |
|                           | -margin                    | meter   | Y        | The maximum distance from the destination the construct may be for the destination to be considered reached.                                        |
| goto                      | waypoint or ::pos{} string |         |          | Moves to the given point                                                                                                                            |
|                           | -maxspeed                  | kph     | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -precision                 |         | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -lockdir                   |         | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -margin                    | meter   | Y        | See &lt;move&gt;                                                                                                                                    |
| print-pos                 |                            |         |          | Prints the current position and current alignment point                                                                                             |
| align-to                  | waypoint or ::pos{} string |         |          | Aligns to the given point                                                                                                                           |
| hold                      |                            |         |          | Stops and returns to the postion at the time of execution, then holds.                                                                              |
| idle                      |                            |         |          | Puts the system into idle mode, engines are off.                                                                                                    |
| turn                      | angle                      | degrees | N        | Turns the construct the specified number of degrees around the Z-axis (up)                                                                          |
| strafe                    | distance                   | meter   | N        | Initiates a strafing move with locked direction.                                                                                                    |
| route-list                |                            |         |          | Lists the currently available routes                                                                                                                |
| route-edit                | name of route              |         | N        | Opens a route for editing                                                                                                                           |
| route-create              | name of route              |         | N        | Creates a new route for editing                                                                                                                     |
| route-save                |                            |         |          | Saves the currently open route                                                                                                                      |
| route-activate            | name of route              |         | N        | Activates the named route and start the flight.                                                                                                     |
|                           | -reverse                   | boolean | Y        | Runs the route in reverse, i.e. the last point becomes the first.                                                                                   |
| route-reverse             |                            |         |          | Reverses the currently open route                                                                                                                   |
| route-delete              | name of route              |         | N        | Deletes the named route                                                                                                                             |
| route-delete-pos          | index of waypoint          | number  | N        | Removes the point at index from the route.                                                                                                          |
| route-move-pos            |                            |         |          | Moves a point from one index to another                                                                                                             |
|                           | -from                      | number  |          | The index to move from                                                                                                                              |
|                           | -to                        |         |          | The index to move to. Positons at and after the position are shifted forward.                                                                       |
| route-add-current-pos     |                            |         |          | Adds the current position to the current route                                                                                                      |
|                           | -maxspeed                  | kph     | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -precision                 |         | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -lockdir                   | boolean | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -margin                    | meter   | Y        | See &lt;move&gt;                                                                                                                                    |
| route-add-named-pos       |                            |         |          |                                                                                                                                                     |
|                           | name of waypoint           |         |          | Adds a named waypoint to the route                                                                                                                  |
|                           | -maxspeed                  | kph     | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -precision                 |         | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -lockdir                   |         | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -margin                    | meter   | Y        | See &lt;move&gt;                                                                                                                                    |
| route-set-all-margins     |                            | meter   | N        | Sets margin on all points in the route to get provided value                                                                                        |
| route-set-all-max-speeds  |                            | km/h    | N        | Sets max speed on all points in the route to get provided value                                                                                     |
| route-print               |                            |         |          | Prints the current route to the console                                                                                                             |
| pos-create-along-gravity  | name of waypoint           |         |          | Creates a waypoint relative to the constructs position along the gravity vector.                                                                    |
|                           | -u                         | meter   | N        | Upward distance; negate to place point downwards the source of gravity                                                                              |
| pos-create-relative       | name of waypoint           |         |          | Creates a waypoint relative to the construct and its current orientation.                                                                           |
|                           | -f                         | meter   | Y        | Forward distance; negate to move backwards.                                                                                                         |
|                           | -u                         | meter   | Y        | Upward distance; negate to move downwards.                                                                                                          |
|                           | -r                         | meter   | Y        | Rightward distance; negate to move leftwards.                                                                                                       |
| pos-print-relative        |                            |         |          | Prints the position relative to the construct and its current orientation.                                                                          |
|                           | -f                         | meter   | Y        | Forward distance; negate to move backwards.                                                                                                         |
|                           | -u                         | meter   | Y        | Upward distance; negate to move downwards.                                                                                                          |
|                           | -r                         | meter   | Y        | Rightward distance; negate to move leftwards.                                                                                                       |
| pos-save-current-as       | name of waypoint           |         | N        | Save the current position as a named waypoint for later use in a route                                                                              |
| pos-save-as               | name of waypoint           |         | N        | Saves the provided position as a named waypoint for later use in a route                                                                            |
|                           | -pos                       | ::pos{} | N        | The position string to save as the given name                                                                                                       |
| pos-list                  |                            |         |          | Lists the saved positions                                                                                                                           |
| pos-delete                |                            |         |          | Deletes a waypoint.                                                                                                                                 |
|                           | name of waypoint           | string  | N        | The waypoint to delete.                                                                                                                             |
| create-gravity-route      | name of route              |         |          | Creates a route by the given name from current position to a point above (or below) at the given distance along gravity.                            |
|                           | -distance                  | number  | N        | The distance of the point above or below (when negative)                                                                                            |
| create-vertical-route     | name of route              |         |          | Creates a route by the given name from current position to a point above (or below) at the given distance using the given values for the up-vector. |
|                           | -distance                  | number  | N        | The distance of the point above or below (when negative)                                                                                            |
|                           | -followGravInAtmo          | boolean | Y        | If specified (default true), an extra point will be added so that the part of the path that is in atmosphere will follow the gravity vector.        |
|                           | -extraPointMargin          | number  | N        | Specifies the margin used for the extra point, default 5 m.                                                                                         |
|                           | -vertX                     | number  | N        | Specifies the X-value of the direction vector (see 'Creating vertical routes').                                                                     |
|                           | -vertY                     | number  | N        | Specifies the Y-value of the direction vector (see 'Creating vertical routes').                                                                     |
|                           | -vertZ                     | number  | N        | Specifies the Z-value of the direction vector (see 'Creating vertical routes').                                                                     |
| set                       |                            |         |          | Sets the specified setting to the specified value                                                                                                   |
|                           | -engineWarmup              | seconds | Y        | Sets the engine warmup time (T50). Set this to that of the engine with longes warmup.                                                               |
|                           | -containerProficiency      | integer | Y        | Sets the container proficiency talent level, 1-5                                                                                                    |
|                           | -fuelTankOptimization      | integer | Y        | Sets the fuel tank optimization talent level, 1-5                                                                                                   |
|                           | -atmoFuelTankHandling      | integer | Y        | Sets the atmo fuel tank handling talent level, 1-5                                                                                                  |
|                           | -spaceFuelTankHandling     | integer | Y        | Sets the space fuel tank handling talent level, 1-5                                                                                                 |
|                           | -rocketFuelTankHandling    | integer | Y        | Sets the rocket fuel tank handling talent level, 1-5                                                                                                |
|                           | -autoShutdownFloorDistance | number  | Y        | Sets the distance at which the system shuts down while in Hold-state, as measured by the 'FloorDetector' telemeter                                  |
|                           | -yawAlignmentThrustLimiter | number  | Y        | Sets the alignment limit angle which yaw must be within before accelerating to the next waypoint.                                                   |
|                           | -showWidgetsOnStart        | boolean | Y        | If true, diagnostics widgets are shown on start up                                                                                                  |
|                           | -routeStartDistanceLimit   | number  | Y        | Sets the maximum allowed activation distance between the construct and the closest point of a route                                                 |
| get                       | See `set`                  |         | Y        | Prints the setting set with the `set` command                                                                                                       |
| get-all                   |                            |         |          | Prints all current settings                                                                                                                         |
| set-full-container-boosts |                            |         |          | Sets all related talents for containers, atmospheric, space and rocket fuel tanks to level 5                                                        |
| show-widgets              |                            | boolean | Y        | Show/hides widgets with diagnostic info                                                                                                             |


## Mass Overload

Each construct has a max cargo mass it is rated for. If you load the construct with more then one or more of the following may happen:

| Event                                                                      | Possible reasons                                                                                                      |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| When taking off from planet, it will start, brake, start repeatedly.       | Too little brake force to counter gravity for the current mass, which causes the math to say max speed of 0 km/h.     |
| When reaching higher atmosphere it may slow down, stop, and start falling. | Engines not being powerful enough, and/or the thin atmosphere causing too much reduction in power, or too heavy load. |

Should you end up in these situations, it is easiest to just disable the controller, and let it fall back down a bit then activate it again. It will then attempt to hold the position it was at when it was started, i.e. brake and activate engines to counter the fall. You can repeat this until you're at an height the engines work again. Having said that, an overloaded ship is still overloaded and bad things are likely to happen.

## Accuracy

The aim is 0.1m accuracy and this is also the default for the all movements. However, during movement, depending on various factors such as engine choice, mass (and thus acceleration), the construct may go off the path slightly. There is a failsafe that triggers if the nearest point on the path is more than 0.5m away (or as defined by the next waypoint), in which case the construct will brake and return to the point at which it went off the path before continuing the route. If you want to override this behavior, you can reactivate the route again which will make the construct move to the closest point on the path from where where it is when you activate the route. This may save some travel distance.

You may also increase the margin on the waypoints to allow a bit more wiggle room during travel, this may be especially useful on waypoints towards which the acceleration/speed is high or the path is diagonal relative to the gravity vector. Alternatively, you can set a maximum speed to reduce acceleration duration and speed.

### A note on non gravity-aligned atmospheric accent/decent and angled flight paths

While it is possible to make routes that are not gravity aligned work, they may be somewhat unreliable. These are the main reasons:

* Atmospheric brakes

  > Quote from NQ-support:
  > The speed is projected on the horizontal plane of the construct. And we add a brake force in that plane in the opposite direction of that projected speed, which induces a vertical force when the ship has a pitch.

  It is this horizontal force that causes the construct to be pushed off the path. The easiest way to work around this is to ensure that the entry to the planet is aligned with the gravity vector by adding an extra point in the route in space directly above the point inside the atmosphere (see `pos-create-along-gravity`). The downside is that this will be a position the construct has to stop at, which prolongs the travel time and increases fuel consumption due to extra acceleration.

* Strong acceleration

  Sideways engines are generally weaker than the main downward pointing engines so when accelerating, the weaker ones may have difficulties to keep the construct on the path.
