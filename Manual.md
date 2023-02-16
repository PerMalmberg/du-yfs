# Yoarii's Flight system

## Overview

The goal of this project was initially to write a flight system capable of working as what is known as a shaft-less space elevator. i.e. vertical movement around a predefined path. The chosen design does however allow for more than just that and is capable of movement in any direction, within limits of the construct it operates. The original target of only vertical movement along the gravity vector was thus surpassed and it is possible to go in a straight line at an angle from the vertical gravity vector. Further, it also allows you to do up-and-over maneuvers where the
construct parks itself on a space platform from whichever direction you desire.

## Routes

Routes is an important concept for this flight system as they are what guides the construct between positions. A route consists of two or more waypoints, a beginning, an end, and any number of waypoints in-between. A waypoint specifies a position in the world. When added to a route a waypoint is associated with other attributes, such as alignment direction and maximum speed. A route can also contain anonymous waypoints; these exists only in one route and can't be reused. Routes are run beginning to end, unless started in reverse.

### Waypoint alignment

The construct will align towards the next point in the route (see setting `yawAlignmentThrustLimiter`), unless that point has a locked alignment direction, in which case the construct will keep that direction while approaching the waypoint. The construct will also automatically lock and hold the direction if the next target point is nearly straight up or down from its current position, when issued a `move` command.

## Elevator Setup Instructions (manual setup)

### Common steps

This procedure outlined below creates a standard route along the gravity vector. From this you can then opt to either expand it to do an automated parking operation from the side onto a platform. It is assumed a space platform is not already in place. If it is, adjustments have to be taken such that the positions added to the route do not cause a collision. The entire procedure can be reversed such that the construct is first placed in space, but some adjustments are needed to the commands, such as negating distances or adding waypoints in a different order.

* Place the construct at its planet starting position.
* In Lua chat, enter the following commands in order, replacing the values as needed.

| Command                                         | Explanation                                                          | Example                                              |
| ----------------------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------- |
| `pos-save-as <pos1>`                            | Saves the current position as the given name                         | `pos-save-as factory`                                |
| `pos-create-along-gravity <pos2> -u <distance>` | Creates a new position at N meters up along the gravity vector       | `pos-create-along-gravity beside-platform -u 200000` |
| `route-create <name>`                           | Creates a new route by the given name                                | `route-create Main`                                  |
| `route-add-named-pos pos1 -lockdir`             | Adds the first position to the route, with a locked alignment point  | `route-add-named-pos factory -lockdir`               |
| `route-add-named-pos pos2 -lockdir`             | Adds the second position to the route, with a locked alignment point | `route-add-named-pos beside-platform -lockdir`       |
| `route-save`                                    | Saves the route and makes it ready for use                           | `route-save`                                         |

* Ensure that the ECU is active and your fuel tanks are filled.
* Activate the remote controller and the route by clicking the "End" button by the name of the route on the screen. This will take you to the second position created earlier. Once there, the construct will hold its position.
* You can now deactivate the remote control and deploy the space core, using the construct as a reference if you so wish.

#### Option 1 - Up-and-over manoeuver

* Ensure that there is at least ten meter of clearance from the bottom of the construct to the floor of the space core where the construct is meant to go from space onto the core. This is needed to prevent the gravity well of the space core from affecting the construct while it enters the volume of the space core.
* Once the space core in place, activate the remote control again and run the following commands.
* Use the `move` and `pos-save-as` commands to create additional positions that should be added to the route to have the construct park where you wish it.
* Open the route using the `route-edit` command, then add the positions to the route using `route-add-named-pos` with the `-lockdir` switch to ensure that the construct points in the direction you wish. Please read up on how it works in the command list below.
* Finally, save the route with `route-save`.

> Note: You can opt to directly add the final waypoints to the route using the `route-add-current-pos` command instead of first creating named positions.

### Option 2 - Standard elevator with space parking using doors as a docking lock.

* With the space core in place, place doors such that when they close, they give support to the construct and also covers the telemeter on the bottom of the construct so that it can detect a 'floor'. You can use logic components to create a circuit that auto-closes the doors when it is in position or use a manual switch.

## Elevator Setup Instructions (automated setup)

Use the `create-vertical-route` command to create a "standard" elevator setup with a route along the gravity vector.

For example, the following command creates a route named `main` starting at the current position with the end position 200km straight up.

`create-vertical-route main -distance 200000`

Once created, follow the steps for setting up the space core in the instructions for a manual setup.

## Shortcuts

| Key         | Description      |
| ----------- | ---------------- |
| Alt-Shift-9 | (Un)locks player |


## Controls (when user is locked in place)

| Key   | Description             |
| ----- | ----------------------- |
| A     | Turn left               |
| S     | Move one step backwards |
| W     | Move one step forward   |
| D     | Turn right              |
| C     | Move one step down      |
| Space | Move one step up        |
| Alt-A | Strafe left             |
| Alt-D | Strafe right            |

## LUA console commands

| Command                   | Parameters/options                 | Unit    | Optional | Description                                                                                                                                         |
| ------------------------- | ---------------------------------- | ------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| step                      | distance                           | meter   | N        | Sets the default step ASWD movement and other commands                                                                                              |
| speed                     | speed                              | kph     | N        | Sets the max default speed for ASWD movement                                                                                                        |
| move                      |                                    |         |          | Initiates a movement relative to the current position                                                                                               |
|                           | -f                                 | meter   | Y        | Forward distance; negate to move backwards.                                                                                                         |
|                           | -u                                 | meter   | Y        | Upward distance; negate to move downwards.                                                                                                          |
|                           | -r                                 | meter   | Y        | Rightward distance; negate to move leftwards.                                                                                                       |
|                           | -maxspeed                          | kph     | Y        | Maximum approach speed                                                                                                                              |
|                           | -precision                         |         | Y        | if true, the approach will use precision mode, i.e. separated thrust and adjustment calculations. Automatically applied for near-vertical movements |
|                           | -lockdir                           | boolean | Y        | if true, locks the direction during the approach to that which the construct had when the command was issued.                                       |
|                           | -margin                            | meter   | Y        | The maximum distance from the destination the construct may be for the destination to be considered reached.                                        |
| goto                      | waypoint or ::pos{} string         |         |          | Moves to the given point                                                                                                                            |
|                           | -maxspeed                          | kph     | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -precision                         |         | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -lockdir                           |         | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -margin                            | meter   | Y        | See &lt;move&gt;                                                                                                                                    |
| print-pos                 |                                    |         |          | Prints the current position and current alignment point                                                                                             |
| align-to                  | waypoint or ::pos{} string         |         |          | Aligns to the given point                                                                                                                           |
| hold                      |                                    |         |          | Stops and returns to the postion at the time of execution, then holds.                                                                              |
| idle                      |                                    |         |          | Puts the system into idle mode, engines are off.                                                                                                    |
| turn         ez-setup     | angle                              | degrees | N        | Turns the construct the specified number of degrees around the Z-axis (up)                                                                          |
| strafe                    | distance                           | meter   | N        | Initiates a strafing move with locked direction.                                                                                                    |
| route-list                |                                    |         |          | Lists the currently available routes                                                                                                                |
| route-edit                | name of route                      |         | N        | Opens a route for editing                                                                                                                           |
| route-create              | name of route                      |         | N        | Creates a new route for editing                                                                                                                     |
| route-save                |                                    |         |          | Saves the currently open route                                                                                                                      |
| route-activate            | name of route                      |         | N        | Activates the named route and start the flight.                                                                                                     |
|                           | -reverse                           | boolean | Y        | Runs the route in reverse, i.e. the last point becomes the first.                                                                                   |
| route-reverse             |                                    |         |          | Reverses the currently open route                                                                                                                   |
| route-delete              | name of route                      |         | N        | Deletes the named route                                                                                                                             |
| route-delete-pos          | index of waypoint                  | number  | N        | Removes the point at index from the route.                                                                                                          |
| route-move-pos            |                                    |         |          | Moves a point from one index to another                                                                                                             |
|                           | -from                              | number  |          | The index to move from                                                                                                                              |
|                           | -to                                |         |          | The index to move to. Positons at and after the position are shifted forward.                                                                       |
| route-add-current-pos     |                                    |         |          | Adds the current position to the current route                                                                                                      |
|                           | -maxspeed                          | kph     | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -precision                         |         | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -lockdir                           | boolean | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -margin                            | meter   | Y        | See &lt;move&gt;                                                                                                                                    |
| route-add-named-pos       |                                    |         |          |                                                                                                                                                     |
|                           | name of waypoint                   |         |          | Adds a named waypoint to the route                                                                                                                  |
|                           | -maxspeed                          | kph     | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -precision                         |         | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -lockdir                           |         | Y        | See &lt;move&gt;                                                                                                                                    |
|                           | -margin                            | meter   | Y        | See &lt;move&gt;                                                                                                                                    |
| route-set-all-margins     |                                    | meter   | N        | Sets margin on all points in the route to get provided value                                                                                        |
| route-set-all-max-speeds  |                                    | km/h    | N        | Sets max speed on all points in the route to get provided value                                                                                     |
| route-print               |                                    |         |          | Prints the current route to the console                                                                                                             |
| route-discard             |                                    |         |          | Discards all changes made to a route and closes it for editing                                                                                      |
| pos-create-along-gravity  | name of waypoint                   |         |          | Creates a waypoint relative to the constructs position along the gravity vector.                                                                    |
|                           | -u                                 | meter   | N        | Upward distance; negate to place point downwards the source of gravity                                                                              |
| pos-save-as               | name of waypoint                   |         | N        | Save the current position as a named waypoint for later use in a route                                                                              |
| pos-list                  |                                    |         |          | Lists the saved positions                                                                                                                           |
| pos-delete                |                                    |         |          | Deletes a waypoint.                                                                                                                                 |
|                           | name of waypoint                   | string  | N        | The waypoint to delete.                                                                                                                             |
| create-vertical-route     | name of route                      |         |          | Creates a route by the given name from current position to a point above (or below) at the given distance along gravity.                            |
|                           | -distance                          | number  | N        | The distance of the point above or below (when negative)                                                                                            |
| set                       |                                    |         |          | Sets the specified setting to the specified value                                                                                                   |
|                           | -engineWarmup                      | seconds | N        | Sets the engine warmup time (T50). Set this to that of the engine with longes warmup.                                                               |
|                           | -containerProficiency              | integer | N        | Sets the container proficiency talent level, 1-5                                                                                                    |
|                           | -fuelTankOptimization              | integer | N        | Sets the fuel tank optimization talent level, 1-5                                                                                                   |
|                           | -atmoFuelTankHandling              | integer | N        | Sets the atmo fuel tank handling talent level, 1-5                                                                                                  |
|                           | -spaceFuelTankHandling             | integer | N        | Sets the space fuel tank handling talent level, 1-5                                                                                                 |
|                           | -rocketFuelTankHandling            | integer | N        | Sets the rocket fuel tank handling talent level, 1-5                                                                                                |
|                           | -autoShutdownFloorDistance         | number  | N        | Sets the distance at which the system shuts down while in Hold-state, as measured by the 'FloorDetector' telemeter                                  |
|                           | -yawAlignmentThrustLimiter         | number  | N        | Sets the alignment limit angle which yaw must be within before accelerating to the next waypoint.                                                   |
|                           | -showWidgetsOnStart                | boolean | N        | If true, diagnostics widgets are shown on start up                                                                                                  |
| get                       | See `set`                          |         | Y        | Gets and prints the setting set with the `set` command                                                                                              |
| get-all                   |                                    |         |          | Prints all current settings                                                                                                                         |
| set-full-container-boosts |                                    |         |          | Sets all related talents for containers, atmospheric, space and rocket fuel tanks to level 5                                                        |
| show-widgets              |                                    | boolean | Y        | Show/hides widgets with diagnostic info                                                                                                             |
| set-waypoint              | name of waypoint or ::pos{} string | string  | N        | Sets the waypoint given my the name of position string                                                                                              |
|                           | -notify                            |         | Y        | If given, a notification is show on screen when the waypoint is set.                                                                                |


## Mass Overload

Each construct has a max cargo mass it is rated for. If you load the construct with more then one or more of the following may happen:

| Event                                                                      | Possible reasons                                                                                                 |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| When taking off from planet, it will start, brake, start repeatedly.       | Too little brake force to counter gravity for the current mass, which causes the math to say max speed of 0 km/h |
| When reaching higher atmosphere it may slow down, stop, and start falling. | Engines not being powerful enough, and/or the thin atmosphere causing too much reduction in power                |

Should you end up in these situations, it is easiest to just disable the controller, and let it fall back down a bit then activate it again. It will then attempt to hold the position it was at when it was started, i.e. brake and activate engines to counter the fall. You can repeat this until you're at an height the engines work again. Having said that, an overloaded ship is still overloaded and bad things are likely to happen.

## Accuracy

The aim is 0.1m accuracy and this is also the default for the all movements. However, during movement, depending on various factors such as engine choice, mass and talents, the construct may go off the path slightly. There is a failsafe that triggers if the nearest point on the path is more than 0.5m away, in which case the construct will calculate the point at which it went off the path and try to return to that point before continuing the route. If you want to override this behavior, you can reactivate the route again which will make the construct move to the closest point on the path from where where it is when you activate the route. This may save some travel distance.