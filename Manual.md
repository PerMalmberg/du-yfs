# Yoarii's Flight system

Please read the entire manual before attempting to perform an installation, there are important information throughout that will impact the choices you make.

- [Yoarii's Flight system](#yoariis-flight-system)
  - [Overview](#overview)
    - [Required elements (for Do-It-Yourself kits)](#required-elements-for-do-it-yourself-kits)
      - [Optional parts](#optional-parts)
    - [Routes and Waypoints](#routes-and-waypoints)
      - [Route vs Floor mode](#route-vs-floor-mode)
      - [Waypoint alignment](#waypoint-alignment)
    - [Skippable waypoints](#skippable-waypoints)
    - [Enclosures](#enclosures)
    - [Floors for parking; ground and space](#floors-for-parking-ground-and-space)
    - [Cargo mass capacity](#cargo-mass-capacity)
  - [Automatic shutdown](#automatic-shutdown)
  - [Integrations](#integrations)
    - [Gate control](#gate-control)
      - [Elevator side](#elevator-side)
    - [Manual switches](#manual-switches)
  - [Fuel gauges](#fuel-gauges)
  - [Installation as an elevator (ground to space)](#installation-as-an-elevator-ground-to-space)
    - [Aligning the elevator to your ground construct](#aligning-the-elevator-to-your-ground-construct)
    - [Creating a route](#creating-a-route)
    - [Route editor](#route-editor)
    - [Custom travel vector for additional elevators](#custom-travel-vector-for-additional-elevators)
  - [Space core placement](#space-core-placement)
  - [Key bindings](#key-bindings)
  - [Manual Controls (when user is locked in place)](#manual-controls-when-user-is-locked-in-place)
  - [Lua console commands](#lua-console-commands)
  - [Mass Overload](#mass-overload)
  - [Accuracy](#accuracy)
    - [Custom / non-gravity aligned travel vectors](#custom--non-gravity-aligned-travel-vectors)
    - [A note on non gravity-aligned atmospheric accent/decent and angled flight paths](#a-note-on-non-gravity-aligned-atmospheric-accentdecent-and-angled-flight-paths)
  - [Shifting gravity wells](#shifting-gravity-wells)
  - [Emergency Controller Unit](#emergency-controller-unit)
  - [Thanks](#thanks)


## Overview

The goal of this project was initially to write a flight system capable of working as what is known as a shaft-less space elevator. i.e. vertical movement around a predefined path. The chosen design does however allow for more than just that and is capable of movement in any direction, within limits of the construct it operates. The original target of only vertical movement along the gravity vector was thus surpassed and it is possible to go in a straight line at an angle from the vertical gravity vector. Further, it also allows you to do up-and-over maneuvers where the construct parks itself on a space platform from whichever direction you desire.

### Required elements (for Do-It-Yourself kits)

* A telemeter named "FloorDetector", pointing downwards
* A data bank named "Routes"
* Optional data bank named "Settings"
* Screen (optional, but strongly recommended)
* Atmospheric engines are required in all direction, except in the upward direction as gravity does the job. Upward engines are used if present.
* In space, you need engines in all directions.
* Aim for 3g for upward lift when fully loaded.
* Don't forget the brakes

#### Optional parts
* Emitter
* Receiver

### Routes and Waypoints

Routes is an important concept for this flight system as they are what guides the construct between positions. A route consists of two or more waypoints, a start, an end, and any number of waypoints in-between. A waypoint specifies a position in the world. When added to a route a waypoint is associated with other attributes, such as alignment direction and maximum speed. A route can also contain anonymous waypoints; these exists only in one route and can't be reused. When traveling along a route, the next waypoint dictates the direction the constructs forward should point in. Normally this is towards the waypoint itself, but it can be locked to another direction. When a route is run in reverse, the previous waypoint determines the alignment direction so that the the construct performs each movement in reverse along the entire route.

#### Route vs Floor mode

By default, the screen will show two buttons for the start and end of each available route. Pressing either will active the route. Below the two buttons, there's a button named "Waypoints" that shows the individual waypoints in the route. If you would rather have a specific route shown as a list of waypoints to select from at startup, i.e. floor-mode, use the command `set -showFloor 'nameOfYourRoute'`. To revert to the default behavior, type `set -showFloor '-'`. Only waypoints that have not been marked as unselectable via the route editor are shown.

#### Waypoint alignment

The construct will align towards the next point in the route (see setting `yawAlignmentThrustLimiter`), unless that point has a locked alignment direction, in which case the construct will keep that direction while approaching the waypoint. The construct will also automatically lock and hold the direction if the next target point is nearly straight up or down from its current position, also when issued a `move` command.

### Skippable waypoints

You can mark a waypoint in the route as skippable. Doing so makes the system ignore that point when calculating the path to travel to the selected waypoint. However, even if a waypoint is marked as such, it is still used to find the closest point on the complete path when a route is activated. In other words, a skippable point is only considered as such while traveling, not when determining what point to first move to to get back onto the path. This may result in that when activating a route while you're currently traveling between two points, the system may tell you you are too far from the route. A shorter description of this behavior is that _paths resulting from skipped points are not used for evaluating distance to the route on activation_.

### Enclosures

If you intend to build an enclosure for the construct remember that physics in Dual Universe creates a hit box around constructs in the shape of a box, not the visual contours. As such your enclosure must be able to fit a box the size of the extreme distances of the construct on all three axes. Leave a margin at least a _full voxel_ (moving vertices does not count, the entire voxel must be deleted)

### Floors for parking; ground and space

When creating floors for any dynamic construct, ensure that the floor fully encompasses the dynamic construct and it does NOT cross core boundaries or it might clip through and fall, or worse, explode.

### Cargo mass capacity

The cargo mass ratings given for constructs are given in _raw mass values_, i.e. _not_ taking mass reduction talents into account. As such, do not blindly look at the mass shown in the inventory interface of DU. Instead, inspect the item/stack and look at the actual mass of the stack - the DU interface show only 75% of the actual mass when the construct is fully boosted.

The rating is based on these prerequisites:
* Take off from near water level at 100% atmosphere.
* Gravity of 1g.
* Atmosphere thickness of Alioth.
* Zero personal talents.
* Construct full boosted with lvl 5 flight/container/tank skills.

From the above it should be understood that taking off from lower atmosphere (such as from a higher point, or a low-atmosphere planet) makes a big difference in capacity. Likewise, coming into atmosphere and stopping at higher up/in low atmosphere is also subject to the same altered performance.

## Automatic shutdown

When the last point in the route is reached, and the telemeter reports a distance less than the one configured, the script will automatically shutdown.

## Integrations

### Gate control

You can setup automatic control of gates or doors, completely automating the travel, this gets you:

* Automatically opened gates/doors on route activation.
* Automatically closed gates/doors when arriving at the final waypoint (also a mid-point in floor mode).

You do _not_ get automatically closed gates/doors on leaving the start of the route.

Elements needed on the space/static construct:
* 1x Receiver
* 1x Emitter
* 1x Programming Board
* 1x Relay (2x if you want to control more than one gate/door)
* 1x XOR operator
* 1x OR operator
* 1x 2-Counter
* 2x Manual Switch
* Any number of gates/doors

Link the following elements on the ground/space construct as follows. You *must* link the element in the order below. Names in [square brackets] identify different elements of the same type, make sure to link to/from the correct one.

1. PB -> Receiver (green link)
2. PB -> Emitter (green link)
3. PB -> Manual Switch [hold] (green link)
4. PB -> Manual Switch [gates] (green link)
5. Manual Switch [hold] -> OR (blue link)
6. Receiver -> Relay (blue link)
7. Relay -> 2-counter (blue link)
8. Relay -> XOR (blue link)
9. 2-counter -> XOR (blue link)
10. XOR -> OR (blue link)
11. OR -> PB (blue link)
12. Manual Switch [gates] -> Relay and/or gates/doors

*PB = Programming Board

Now copy the _contents_ of the latest released [Json file from here](https://github.com/PerMalmberg/du-yfs-gate-control/releases/latest), right-click on the Programming Board, open the Advanced menu and click `Paste Lua Configuration from clipboard`. Ensure you get a success message on screen.

Right-click on the programming board and click `Edit Lua parameters` and set a unique communication channel, using alpha numerical characters only, no spaces. Ensure you keep the quotation marks! The channel must be unique per elevator/gate set or they will interfere with each other. Click OK to close the dialog.
Now activate the programming board to complete the setup of the worker side, look in Lua chat for any errors printed and adjust accordingly.

> Note
> * Gate Control is only active while running a route, not when manually controlling the construct with keys or via the `move` command.
> * Gates are only opened at route activation if closer to a controlled point than configured with setting `openGateMaxDistance`.
> * Gate control only works as long as the receiving elements are loaded. Elements such as those used on the receiver side are unloaded by the game at fairly short distances so place them as close to the elevator as possible. In the case of multi-floor, a central position to all waypoints is recommended
> * Gate control adds a few seconds after activating a route and before any movements happens. Look in Lua chat to see if it is waiting for the doors to open or close.

#### Elevator side

The receiver *must* be linked on the first slot of the remote controller. If your construct didn't come with this pre-linked, you do this easiest by removing all links, then linking from the Remote Controller to the Receiver, followed by linking the Core, Telemeter, Screen, Databank(s) and Emitter.

In Lua chat, you must run the command `set -commChannel CHANNEL`, replacing `CHANNEL` with the same channel name you used on the programming board on the space/static construct so that they can communicate with each other. Now restart the elevator so that the channel can be applied.  Next, for each point in the route you want the elevator to control the gates, open the route for editing then click to enable gate control using the on-screen UI for the points you want to control gates at. Finish by saving the route.

For example, the most common setup is to have gates/doors only at the space station. If we assume the first point in the route is at the ground, run `route-set-gate-control -atStart false -atEnd true`.

### Manual switches

If linked to the remote controller, the script can control two Manual Switches, depending on their names:

* A Manual Switch named "FollowGate" will be activated whenever the gate control opens the gates and deactivated when gates are closed.
* A Manual Switch named "FollowRemote" will follow the state of the Remote Controller.

## Fuel gauges

The screen shows up to four fuel tanks of each of the atmospheric and space types. It chooses the ones to display based on the lowest percentage and as such you can always see how close you are to run out of fuel, regardless of how many fuel tanks you have.

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
      local fmt = "align-to-vector -x %0.14f -y %0.14f -z %0.14f"
      local s = string.format(fmt, v.x, v.y, v.z)
      slot1.setCenteredText(s)
      unit.exit()
      ```
    * Align to backwards vector
      ```lua
      local Vec3 = require("cpml/vec3")
      local v = -Vec3(construct.getWorldOrientationForward())
      local fmt = "align-to-vector -x %0.14f -y %0.14f -z %0.14f"
      local s = string.format(fmt, v.x, v.y, v.z)
      slot1.setCenteredText(s)
      unit.exit()
      ```
    * Align to right vector
      ```lua
      local Vec3 = require("cpml/vec3")
      local v = Vec3(construct.getWorldOrientationRight())
      local fmt = "align-to-vector -x %0.14f -y %0.14f -z %0.14f"
      local s = string.format(fmt, v.x, v.y, v.z)
      slot1.setCenteredText(s)
      unit.exit()
      ```
    * Align to left vector
      ```lua
      local Vec3 = require("cpml/vec3")
      local v = -Vec3(construct.getWorldOrientationRight())
      local fmt = "align-to-vector -x %0.14f -y %0.14f -z %0.14f"
      local s = string.format(fmt, v.x, v.y, v.z)
      slot1.setCenteredText(s)
      unit.exit()
      ```

1. Start the Programming Board and copy the command from the screen (CTRL-L to to open editor while pointing to the screen).
   * The command is the part in the `text = ....` line of the screen code. Do not copy the quotation marks.
2. Start the elevator, enter manual control mode and raise it up slightly using the `move` command. Manual mode is needed to prevent it to shutdown automatically.
3. Paste the command into Lua-chat and press enter to perform the alignment.
   * Showing the widgets (`show-widgets 1`) and looking in the "Rotation" widget, under "Axis/Yaw", at the _offset_ value will show 0 when it is aligned.
4. Once aligned, either hold C or use the `move` command to set it down again.
5. Turn off the elevator.

### Creating a route

1. Decide on what distance above (_not_ height above sea level) you want the route to stop at.
2. Decide on a name for the route. You can use spaces in it, but you must surround it with single quotes, like so: `'a name'`. Double quotes do currently not work due to a bug in DU. Keep the name at 14 characters or less so it fits on the screen.
3. Activate the elevator.
4. In Lua chat, type:
   `create-vertical-route 'route name' -distance 12345`, replacing values as appropriate.
   * If this isn't your first elevator, and you want this one to run parallel to the first one, add the `-distance`,  `-x`, `-y`, and `-z` arguments you get using the instructions in the "[Travel vector for additional elevators](#travel-vector-for-additional-elevators)" section.

     Example: `create-vertical-route 'route name' -distance 100000 -x 0.1234 -y 0.5678 -z 0.9012`

The screen will now show the name of your route with two buttons, one for the start (ground) and end (space). Simply clicking these buttons will make the elevator move to those respective locations.

You can now expand on this route by adding additional points to it (see [Key-bindings](#key-bindings), [Manual Controls](#manual-controls-when-user-is-locked-in-place) and [Lua console commands](#lua-console-commands)), do do up-and-over maneuvers, sideways movements etc., to fit your exact needs. Needless to say, any additional movement increases fuel consumption. This is especially true in atmosphere where gravity generally is higher.

### Route editor

The on-screen route editor (accessible from the main screen) allows you to perform the following operations on a route.
* Add a waypoint to a route, with or without direction information.
* Remove a waypoint from a route.
* Reorder waypoints in a route.
* Set a waypoint as skippable, allowing it to be skipped when moving along the route.
* Set a waypoint as unselectable, which will hide it from from the floor-selection screen.
* Add current pos with or without direction information.
* Discard any changes made to the route.
* Save the route.

If there are more waypoints that fit on a single screen, use the arrows below the list to switch to another page.

### Custom travel vector for additional elevators

To ensure that elevators end up at the same relative distances in space as they have on the ground, you need to make them use the same travel direction. To do so, follow these instructions:

> Note: This only looks at the two first points in the route. If you want to use other points, you can use the `sub-pos` command.

1. Select one elevator as the reference elevator.
2. Activate the elevator
3. Choose the route you want to use as a reference and type the following command in Lua chat, replacing with your route name.

   > `get-parallel-from-route YOUR_ROUTE_NAME`

   This will print something like this:
   > `[I] -distance 123456 -x 0.123456 -y 0.456789 -z 0.789012`

5. Copy this from the chat (right click on the Lua chat tab to access menu) and paste it into your favorite text editor and extract the relevant parts after the `[I]`, you'll find it at the very end of the text. Ensure that you get all the decimals.

See the [accuracy section](#custom-travel-vectors) for additional information.

## Space core placement

When placing the space core/construct, using the snapping mode on the elevator can make it much easier to align it correctly. Just keep in mind where the parking spot is meant to be etc.

Hint: To activate snapping mode, point into empty space, then click middle mouse button, then left click on the elevator to select it as a reference construct and move the new core/construct using normal adjustment keys. If you're doing it alone, the ECU must be holding the elevator in place, you can't actively run the remote controller while deploying a core/construct.

## Key bindings

| Key         | Description                                                      |
| ----------- | ---------------------------------------------------------------- |
| Alt-Shift-9 | (Un)locks player / enters/exists manual control (WSAD etc.) mode |


## Manual Controls (when user is locked in place)

| Key (default key binding) | Description                 |
| ------------------------- | --------------------------- |
| A                         | Turn left                   |
| S                         | Move backwards              |
| W                         | Move forward                |
| D                         | Turn right                  |
| C                         | Move down                   |
| Space                     | Move  up                    |
| Alt+A / Q                 | Strafe left                 |
| Alt+D / E                 | Strafe right                |
| Mouse scroll wheel        | Increase/decrease max speed |

> Note: Manual control of heavy constructs are much less accurate (especially during vertical movements). Don't expect the same maneuverability as a tiny 1.5t construct.

## Lua console commands

| Command                   | Parameters/options          | Unit/type     | Optional | Description                                                                                                                                                                                                                                                                                              |
| ------------------------- | --------------------------- | ------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| move                      |                             |               |          | Initiates a movement relative to the current position                                                                                                                                                                                                                                                    |
|                           | -f                          | meter         | Y        | Forward distance; negate to move backwards.                                                                                                                                                                                                                                                              |
|                           | -u                          | meter         | Y        | Upward distance; negate to move downwards.                                                                                                                                                                                                                                                               |
|                           | -r                          | meter         | Y        | Rightward distance; negate to move leftwards.                                                                                                                                                                                                                                                            |
|                           | -forceVerticalUp            | boolean       | Y        | If true, forces upside to align away from vertical up, regardless of `pathAlignmentAngleLimit`. Default true.                                                                                                                                                                                            |
|                           | -maxspeed                   | km/h          | Y        | Maximum approach speed                                                                                                                                                                                                                                                                                   |
|                           | -lockdir                    | boolean       | Y        | if true, locks the direction during the approach to that which the construct had when the command was issued.                                                                                                                                                                                            |
|                           | -margin                     | meter         | Y        | The maximum distance from the destination the construct may be for the destination to be considered reached.                                                                                                                                                                                             |
| goto                      | waypoint or ::pos{} string  |               |          | Moves to the given point                                                                                                                                                                                                                                                                                 |
|                           | -maxspeed                   | km/h          | Y        | See &lt;move&gt;                                                                                                                                                                                                                                                                                         |
|                           | -lockdir                    |               | Y        | See &lt;move&gt;                                                                                                                                                                                                                                                                                         |
|                           | -margin                     | meter         | Y        | See &lt;move&gt;                                                                                                                                                                                                                                                                                         |
|                           | -offset                     | meter         | Y        | If specified, the distance will be shortened by this amount, i.e. stop before reaching the position. Good for approaching unknown locations.<br/>Negative offsets means the other side of the point, i.e. overshoot.                                                                                     |
|                           | -forceVerticalUp            | boolean       | Y        | If true, forces upside to align away from vertical up, regardless of `pathAlignmentAngleLimit`. Default true.                                                                                                                                                                                            |
| print-pos                 |                             |               |          | Prints the current position and current alignment point                                                                                                                                                                                                                                                  |
| align-to                  | waypoint or ::pos{} string  |               |          | Aligns to the given point or named waypoint                                                                                                                                                                                                                                                              |
| align-to-vector           |                             |               |          | Aligns to the given point, as given by a 3D-vector. See section "Aligning the elevator to your ground construct"                                                                                                                                                                                         |
|                           | -x                          | number        | N        | X-component of the vector                                                                                                                                                                                                                                                                                |
|                           | -y                          | number        | N        | X-component of the vector                                                                                                                                                                                                                                                                                |
|                           | -z                          | number        | N        | X-component of the vector                                                                                                                                                                                                                                                                                |
| floor                     | name of route               | string        | N        | Shows the named route in floor-mode.                                                                                                                                                                                                                                                                     |
| hold                      |                             |               |          | Stops and returns to the position at the time of execution, then holds.                                                                                                                                                                                                                                  |
| idle                      |                             |               |          | Puts the system into idle mode, engines are off.                                                                                                                                                                                                                                                         |
| turn                      | angle                       | degrees       | N        | Turns the construct the specified number of degrees around the Z-axis (up)                                                                                                                                                                                                                               |
| strafe                    | distance                    | meter         | N        | Initiates a strafing move with locked direction.                                                                                                                                                                                                                                                         |
| route-list                |                             |               |          | Lists the currently available routes                                                                                                                                                                                                                                                                     |
| route-edit                | name of route               |               | N        | Opens a route for editing                                                                                                                                                                                                                                                                                |
| route-create              | name of route               |               | N        | Creates a new route and opens it for editing                                                                                                                                                                                                                                                             |
| route-save                |                             |               |          | Saves the currently open route, and closes it for editing.                                                                                                                                                                                                                                               |
| route-activate            | name of route               |               | N        | Activates the named route and starts the flight.                                                                                                                                                                                                                                                         |
|                           | -index                      | integer       | Y        | Specifies which waypoint index that shall be the final destination. Default is '0', meaning the last point in the route.                                                                                                                                                                                 |
| route-delete              | name of route               |               | N        | Deletes the named route                                                                                                                                                                                                                                                                                  |
| route-rename              |                             |               |          | Renames a route                                                                                                                                                                                                                                                                                          |
|                           | -from                       | string        |          | The name of the route to rename                                                                                                                                                                                                                                                                          |
|                           | -to                         | string        |          | The new name of the route                                                                                                                                                                                                                                                                                |
| route-delete-pos          | index of waypoint           | number        | N        | Removes the point at index from the route.                                                                                                                                                                                                                                                               |
| route-move-pos            |                             |               |          | Moves a point from one index to another                                                                                                                                                                                                                                                                  |
|                           | -from                       | number        |          | The index to move from                                                                                                                                                                                                                                                                                   |
|                           | -to                         |               |          | The index to move to. Positions at and after the position are shifted forward.                                                                                                                                                                                                                           |
| route-move-pos-forward    | position index, 1..n        | number        | N        | Moves the position at the given index one step forward.                                                                                                                                                                                                                                                  |
| route-move-pos-back       | position index, 1..n        | number        | N        | Moves the position at the given index one step backward.                                                                                                                                                                                                                                                 |
| route-add-current-pos     |                             |               |          | Adds the current position to the current route                                                                                                                                                                                                                                                           |
|                           | -maxspeed                   | km/h          | Y        | See &lt;move&gt;                                                                                                                                                                                                                                                                                         |
|                           | -lockdir                    | boolean       | Y        | See &lt;move&gt;                                                                                                                                                                                                                                                                                         |
|                           | -margin                     | meter         | Y        | See &lt;move&gt;                                                                                                                                                                                                                                                                                         |
| route-add-named-pos       |                             |               |          |                                                                                                                                                                                                                                                                                                          |
|                           | name of waypoint            |               |          | Adds a named waypoint to the route                                                                                                                                                                                                                                                                       |
|                           | -maxspeed                   | km/h          | Y        | See &lt;move&gt;                                                                                                                                                                                                                                                                                         |
|                           | -lockdir                    |               | Y        | See &lt;move&gt;                                                                                                                                                                                                                                                                                         |
|                           | -margin                     | meter         | Y        | See &lt;move&gt;                                                                                                                                                                                                                                                                                         |
| route-set-all-margins     |                             | meter         | N        | Sets margin on all points in the route to the provided value                                                                                                                                                                                                                                             |
| route-set-all-max-speeds  |                             | km/h          | N        | Sets max speed on all points in the route to get provided value                                                                                                                                                                                                                                          |
| route-set-pos-option      | -ix                         | number        | N        | Defines the first point to set the respective options on, in the currently edited route.                                                                                                                                                                                                                 |
|                           | -endIx                      | number        | Y        | Defines the optional ending index on which to set the respective option on. Use this to set the same options on several points at the same time.                                                                                                                                                         |
|                           | -toggleSkippable            |               | Y        | Toggles the skippable option of the point. A skippable point may be skipped when traveling to another point in the route.                                                                                                                                                                                |
|                           | -toggleSelectable           |               | Y        | Toggles the selectable option of the point. A selectable point will show up in the list of available points when a route is show in floor-mode.                                                                                                                                                          |
|                           | -margin                     | meter         | Y        | Sets the margin, in meters, for the point.                                                                                                                                                                                                                                                               |
|                           | -maxSpeed                   | km/h          | Y        | Sets the max speed, in km/h for the point.                                                                                                                                                                                                                                                               |
|                           | -finalSpeed                 | km/h          | Y        | Sets the final speed, i.e. the speed to have when reaching the point.                                                                                                                                                                                                                                    |
|                           | -toggleGate                 |               | Y        | Toggles the gate control for the point.                                                                                                                                                                                                                                                                  |
| route-print-pos-options   |                             | number        | N        | Prints the options of the given point in the currently open route.                                                                                                                                                                                                                                       |
| route-print               |                             |               |          | Prints the current route to the console                                                                                                                                                                                                                                                                  |
| pos-create-along-gravity  | name of waypoint            |               |          | Creates a waypoint relative to the constructs position along the gravity vector.                                                                                                                                                                                                                         |
|                           | -u                          | meter         | N        | Upward distance; negate to place point downwards the source of gravity                                                                                                                                                                                                                                   |
| pos-create-relative       | name of waypoint            |               |          | Creates a waypoint relative to the construct and its current orientation.                                                                                                                                                                                                                                |
|                           | -f                          | meter         | Y        | Forward distance; negate to move backwards.                                                                                                                                                                                                                                                              |
|                           | -u                          | meter         | Y        | Upward distance; negate to move downwards.                                                                                                                                                                                                                                                               |
|                           | -r                          | meter         | Y        | Rightward distance; negate to move leftwards.                                                                                                                                                                                                                                                            |
| pos-print-relative        |                             |               |          | Prints the position relative to the construct and its current orientation.                                                                                                                                                                                                                               |
|                           | -f                          | meter         | Y        | Forward distance; negate to move backwards.                                                                                                                                                                                                                                                              |
|                           | -u                          | meter         | Y        | Upward distance; negate to move downwards.                                                                                                                                                                                                                                                               |
|                           | -r                          | meter         | Y        | Rightward distance; negate to move leftwards.                                                                                                                                                                                                                                                            |
| pos-save-current-as       |                             |               |          | Save the current position as a named waypoint for later use in a route                                                                                                                                                                                                                                   |
|                           | -name                       | string        | Y        | If given, this is the name to save as.                                                                                                                                                                                                                                                                   |
|                           | -auto                       |               | Y        | If specified automatically created a waypoint by name WPnnn, such as WP001. Takes precedence over `-auto`                                                                                                                                                                                                |
| pos-save-as               | name of waypoint            |               | N        | Saves the provided position as a named waypoint for later use in a route                                                                                                                                                                                                                                 |
|                           | -pos                        | ::pos{}       | N        | The position string to save as the given name                                                                                                                                                                                                                                                            |
| pos-rename                |                             |               |          | Renames the waypoint and all references to it in routes.                                                                                                                                                                                                                                                 |
|                           | -old                        |               | N        | Name of the existing waypoint                                                                                                                                                                                                                                                                            |
|                           | -new                        |               | N        | New name of the waypoint                                                                                                                                                                                                                                                                                 |
| pos-list                  |                             |               |          | Lists the saved positions                                                                                                                                                                                                                                                                                |
| pos-delete                |                             |               |          | Deletes a waypoint.                                                                                                                                                                                                                                                                                      |
|                           | name of waypoint            | string        | N        | The waypoint to delete.                                                                                                                                                                                                                                                                                  |
| create-vertical-route     | name of route               |               |          | Creates a route by the given name from current position to a point above (or below) at the given distance along gravity or optionally, using the given values for the up-vector. The start end end points are given a margin of 0.3m to counter small construct movements when the controller turns off. |
|                           | -distance                   | number        | N        | The distance of the point above or below (when negative)                                                                                                                                                                                                                                                 |
|                           | -followGravInAtmo           |               | Y        | If specified an extra point will be added so that the part of the path that is in atmosphere will follow the gravity vector, regardless of the specified custom vector.                                                                                                                                  |
|                           | -extraPointMargin           | number        | N        | Specifies the margin used for the extra point, default 5 m.                                                                                                                                                                                                                                              |
|                           | -x                          | number        | N        | Specifies the X-value of the direction vector (see 'Travel vector for additional elevators').                                                                                                                                                                                                            |
|                           | -y                          | number        | N        | Specifies the Y-value of the direction vector (see 'Travel vector for additional elevators').                                                                                                                                                                                                            |
|                           | -z                          | number        | N        | Specifies the Z-value of the direction vector (see 'Travel vector for additional elevators').                                                                                                                                                                                                            |
| print-vertical-up         |                             |               |          | Prints the negative of the gravitational up-vector, i.e. 'up', at the current location. Used to get values for use with `create-vertical-route`.                                                                                                                                                         |
| get-parallel-from-route   |                             |               |          | Prints the direction and distance from the first to the second point in the route in a format directly usable by the `create-vertical-route` command. Can be used to create a route parallel to another one.                                                                                             |
| sub-pos                   | A `::pos{}` string          | string        | N        | Prints the direction and distance in a format directly usable by the `create-vertical-route` command. Can be used to create a route parallel to another one.                                                                                                                                             |
|                           | -sub                        | `::pos{}`     | Y        | If proved this is the subtrahend. If left out, the current position is used.                                                                                                                                                                                                                             |
| closest-on-line           |                             |               | N        | Calculates the closest point on the line that passes through point a and b.                                                                                                                                                                                                                              |
|                           | -a                          | `::pos{}`     | N        | Point a                                                                                                                                                                                                                                                                                                  |
|                           | -a                          | `::pos{}`     | N        | Point b                                                                                                                                                                                                                                                                                                  |
| set                       |                             |               |          | Sets the specified setting to the specified value                                                                                                                                                                                                                                                        |
|                           | -engineWarmup               | seconds       | Y        | Sets the engine warmup time (T50). Set this to that of the engine with longes warmup.                                                                                                                                                                                                                    |
|                           | -containerProficiency       | integer       | Y        | Sets the container proficiency talent level, 1-5                                                                                                                                                                                                                                                         |
|                           | -fuelTankOptimization       | integer       | Y        | Sets the fuel tank optimization talent level, 1-5                                                                                                                                                                                                                                                        |
|                           | -atmoFuelTankHandling       | integer       | Y        | Sets the atmospheric fuel tank handling talent level, 1-5                                                                                                                                                                                                                                                |
|                           | -spaceFuelTankHandling      | integer       | Y        | Sets the space fuel tank handling talent level, 1-5                                                                                                                                                                                                                                                      |
|                           | -rocketFuelTankHandling     | integer       | Y        | Sets the rocket fuel tank handling talent level, 1-5                                                                                                                                                                                                                                                     |
|                           | -autoShutdownFloorDistance  | number        | Y        | Sets the distance at which the system shuts down while in Hold-state, as measured by the 'FloorDetector' telemeter                                                                                                                                                                                       |
|                           | -yawAlignmentThrustLimiter  | number        | Y        | Sets the alignment limit angle which yaw must be within before accelerating to the next waypoint.                                                                                                                                                                                                        |
|                           | -showWidgetsOnStart         | boolean       | Y        | If true, diagnostics widgets are shown on start up                                                                                                                                                                                                                                                       |
|                           | -routeStartDistanceLimit    | number        | Y        | Sets the maximum allowed activation distance between the construct and the closest point of a route                                                                                                                                                                                                      |
|                           | -throttleStep               | number        | Y        | Sets the step size of the throttle in manual control mode in percent, default 10                                                                                                                                                                                                                         |
|                           | -manualControlOnStartup     | boolean       | Y        | If true, manual mode is activated on startup.                                                                                                                                                                                                                                                            |
|                           | -turnAngle                  | degrees       | Y        | Sets the turn angle per key press for the manual control mode.                                                                                                                                                                                                                                           |
|                           | -minimumPathCheckOffset     | meter         | Y        | Sets the minimum allowed offset from the path during travel at which the construct will stop to and return to the path. Default 2m.                                                                                                                                                                      |
|                           | -showFloor                  | name of route | Y        | If set, causes the named route to be displayed in floor-mode on startup. To disable, use '-' as the route name.                                                                                                                                                                                          |
|                           | -pathAlignmentAngleLimit    | degrees       | Y        | The threshold angle that determines if the construct will align to the flight path or the gravity vector. Default: 10 degrees. Set to 0 to disable path alignment.                                                                                                                                       |
|                           | -pathAlignmentDistanceLimit | meter         | Y        | The threshold distance that determines if the construct will align to the flight path or the gravity vector. Default: 200m.                                                                                                                                                                              |
|                           | -setWaypointAlongRoute      | boolean       | Y        | If true, the next point in the route will become your waypoint.                                                                                                                                                                                                                                          |
|                           | -commChannel                | string        | Y        | If set to anything but an empty string, this enables gate controls and defines the channel used to communicate with other constructs on. Must restart elevator when changed.                                                                                                                             |
|                           | -shutdownDelayForGate       | number        | Y        | The number of seconds to wait in the at the final position after detecting a floor to land on before shutting down. Intended for when you have a gate above or beside the elevator that you want to close. Default 2 seconds.                                                                            |
|                           | -openGateWaitDelay          | number        | Y        | The number of seconds to wait on gates to be fully opened before starting any movement. Default 3 seconds. Reduce this if your gates are _fully_ open in a shorter time.                                                                                                                                 |
|                           | -openGateMaxDistance        | number        | Y        | The elevator must be closer than this to a point in the route that has gate control activated for gate control to open gates. Default 10m. This is to avoid waiting on gates when activating a route in between two points.                                                                              |
|                           | -dockingMode                | number (1..3) | Y        | Sets the docking mode. 1 = Manual (by default use ALT+T/Y dock/undock), 2 = Automatic, 3 = Automatic, but only own constructs.                                                                                                                                                                           |
| get                       | See `set`                   |               | Y        | Prints the setting set with the `set` command, don't add the leading `-`.                                                                                                                                                                                                                                |
| get-all                   |                             |               |          | Prints all current settings. Don't add the "-" before the argument. Example: `get turnAngle`.                                                                                                                                                                                                            |
| reset-settings            |                             |               |          | Resets all settings to their defaults.                                                                                                                                                                                                                                                                   |
| set-full-container-boosts |                             |               |          | Sets all related talents for containers, atmospheric, space and rocket fuel tanks to level 5                                                                                                                                                                                                             |
| show-widgets              |                             | boolean       | Y        | Show/hides widgets with diagnostic info                                                                                                                                                                                                                                                                  |


Please note that deleting named waypoints do not update routes that reference them. You can create a new one with the same name as the one deleted, but until you do, any route that referenced it will not be usable.

## Mass Overload

Each construct has a max cargo mass it is rated for. If you load the construct with more then one or more of the following may happen:

| Event                                                                      | Possible reasons                                                                                                      |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| When taking off from planet, it will start, brake, start repeatedly.       | Too little brake force to counter gravity for the current mass, which causes the math to say max speed of 0 km/h.     |
| When reaching higher atmosphere it may slow down, stop, and start falling. | Engines not being powerful enough, and/or the thin atmosphere causing too much reduction in power, or too heavy load. |

Should you end up in these situations, it is easiest to just disable the controller (and the ECU), and let it fall back down a bit then activate it again. It will then attempt to hold the position it was at when it was started, i.e. brake and activate engines to counter the fall. You can repeat this until you're at an height the engines work again. Having said that, an overloaded ship is still overloaded and bad things are likely to happen.

## Accuracy

The aim is 0.1m accuracy and this is also the default for the all movements. However, depending on various factors such as engine choice, mass (and thus acceleration), the construct may go off the path slightly. There is a failsafe that triggers if the nearest point on the path too far off (see setting `minimumPathCheckOffset`, or as defined by the next waypoint), in which case the construct will brake and return to the point at which it went off the path before continuing the route. If you want to override this behavior, you can reactivate the route again which will make the construct move to the closest point on the path from where where it is when you reactivate the route.

You may also increase the margin on specific waypoints to allow more wiggle room during travel, this may be especially useful on waypoints towards which the acceleration/speed is high or the path is diagonal relative to the gravity vector. Alternatively, you can set a maximum speed to reduce acceleration duration and speed.

The two settings `pathAlignmentAngleLimit` and `pathAlignmentDistanceLimit` control if/when the construct aligns itself to the current flight path. While doing so significantly increases the ability to stay on the path (especially during atmospheric descent), it may cause issues if the approach to the parking position is at an angle and it has been encapsulated. The alignment only happens if the distance to the next *and* previous waypoint is greater than `pathAlignmentDistanceLimit` and if the angle to the gravity vector is less than `pathAlignmentAngleLimit`. Should you wish to disable the alignment completely, set `pathAlignmentAngleLimit` to 0.

### Custom / non-gravity aligned travel vectors
The further the distance is between the reference elevator and any additional one, the harder it is to stay exactly on the desired path, especially during strong (de)acceleration. The script will attempt to bring the elevator back to the path in time for the end position, but if this becomes a problem you can add an additional point in the route to force it back to the path prior to reaching the final point.

### A note on non gravity-aligned atmospheric accent/decent and angled flight paths

While it is possible to make routes that are not gravity aligned work, they may be somewhat unreliable. These are the main reasons:

* Atmospheric brakes

  > Quote from NQ-support:
  > The speed is projected on the horizontal plane of the construct. And we add a brake force in that plane in the opposite direction of that projected speed, which induces a vertical force when the ship has a pitch.

  It is this horizontal force that causes the construct to be pushed off the path. The easiest way to work around this is to ensure that the entry to the planet is aligned with the gravity vector by adding an extra point in the route in space directly above the point inside the atmosphere (see `pos-create-along-gravity`). The downside is that this will be a position the construct has to stop at, which prolongs the travel time and increases fuel consumption due to extra acceleration.

* Strong acceleration

  Sideways engines are generally weaker than the main downward pointing engines so when accelerating, the weaker ones may have difficulties to keep the construct on the path.

## Shifting gravity wells

As described in [Accuracy](#accuracy), the script aligns either to gravity or the travel path. When gravity direction changes, such as near Thades' moonlets (where they appear to be the sum of the different gravity wells depending on the location of the construct), the script will adjust its alignment accordingly. Another case where this will happen (theoretically, not actually tested at the time of writing this) is when traveling between planets such as Alioth and Haven/Sanctuary; at the midpoint the script should flip over 180 degrees.

This means that a route starting at the surface of Thades and ending among the moonlets will have different alignment directions along the travel path. As such, a space construct placed based on the elevator's alignment in space will not point exactly away from Thades, but clearly be at an angle to the planet. Please keep all this in mind when building your space construct.

A way to work around this is to add an extra point in the route within the distance of `pathAlignmentDistanceLimit` so that you force the alignment to be along gravity for the duration of the travel between the points.

## Emergency Controller Unit

When running on an ECU, the script only do two things:
* Attempts to hold the position it has when activated
* Detect a floor, and if detected it shuts down.

The requirements for linking are the same as for when running on a controller.

## Thanks

Special thanks goes out to these players:
* Vargen - for our endless discussions and a fountain of ideas.
* Zcrewball - for doing the industry supplying an endless number of sacrificial elements.
* De Overheid - Helping out with the visual design.
* Emma Roid, 2Bitter, Petra25, AceMan - for feedback

