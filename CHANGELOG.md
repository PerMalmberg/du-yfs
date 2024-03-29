# YFS Changelog

All notable changes to this project will be documented in this file. The version number refers to the version printed in Lua chat for the control unit/ECU, not the one displayed on the screen in offline mode.

## 1.7.1 - 2023-12-10

### Changed
* Did some adjustments relating to small movements on larger constructs where it could end up in a state where brakes engaged while trying to accelerate from 0 speed.
* Adjusted margin used when returning to path after slipping of it. It now uses the `minimumPathCheckOffset` as the margin.

## 1.7.0 - 2023-12-08

### Added
* New setting `autoPitch` which, if true, enables automatic pitch when moving forward and up/down. Enabled by using command `free-mode` or by setting it manually. Intended for constructs mainly controlled using manual controls.

### Fixed
* Corrected a thrust calculation error regarding path adjustments that became evident when using only hovers as lift.

## 1.6.0 - 2023-11-17

> NOTE: If your construct mainly is controlled manually, you'll want to run the `free-mode` command after updating to this version, or set the new settings manually to make the construct function as it did previously.

### Fixed
* The change made in 1.5.2 for thrust, while doing what it should, turned out to cause other issues with certain paths, especially when doing the "flip maneuver" when approaching a planet, whereby engines pushed the construct of the path. To improve on this change, `pitchAlignmentThrustLimiter` and `rollAlignmentThrustLimiter` settings have been added to prevent engines from firing if not properly aligned.
* A major refactor of the thrust control was made to handle certain directional transitions along a route. As a result of this a bug was found and fixed that prevented full use of downward facing engines.
* `pos-save-current-as` now functions again, but had to bring back the -name parameter since the command parser doesn't support optional non-parameters.

### Added
* A new setting `autoBrakeDelay` (used in conjunction with `autoBrakeAngle`) has been added as a means to adjust how fast the brakes activate when moving at and angle to the intended path or acceleration vector. The default value is 1, intended for construct using "strict mode".

## 1.5.3 - 2023-11-11

### Fixed
  * Squashed bug that caused "Waypoints" button on route screen as well as the `floor` command not to function.

## 1.5.2 - 2023-11-10

### Changed
* Change thrust vector math to ensure sideways engines don't result in near-zero thrust in main thrust direction.
  * NOTE: This may result in less exact
* Adjusted default values for yaw/pitch/roll PIDs to reduce over shoots on small constructs. To reset yours to new defaults, either run `reset-settings` or set them manually to 10/0/800 using the `set -light[p|i|d]` command)
* Adjusted turn angle to 8 degrees for manual control. To set yours, run `free-mode`.

## 1.5.1 - 2023-11-04

### Changed
* `pos-save-current-as` no longer requires the `-name` parameter and instead just takes a single argument as the name.

### Fixed
* No longer prints double messages when storing current position as a waypoint.
* Docking mode now applies properly on startup.

## 1.5.0 - 2023-10-27

### Added
* New setting `autoBrakeAngle` to control at what angle offset from the intended path brakes automatically engage.
* Press "G" (Lua binding "gear"), to engage auto parking.
  * New setting `parkMaxSpeed` to set maximum parking speed.
* Auto-dock/undock (EXPERIMENTAL)
  * Press `CTRL + SHIFT + G` to perform an undocking operation.
    * New setting `parkMargin` to control the margin of the parking route.
    * New setting `parkVertDist` to control how much to move vertically during the undocking.
    * New setting `parkForwardDist` to control how much forward to move during the undocking.
  * New setting `parkUseGates` to control if gates should be controlled during the auto-dock/park operation.
  * Press `SHIFT + G` to automatically return to a saved parking position and run the undocking procedure in reverse.

### Fixed
* Corrected some broken math that had went unnoticed since pre v1.0.
* Fixed manual movement quirks introduced in 1.4.1. Oops!

### Changed
* Code size reduction
* If a key that can't be loaded exist on a data bank, the script will now log that and continue loading remaining keys instead of showing the red "script error" message in the control unit widget.

## 1.4.1 - 2023-10-14

### Fixed
* When running a route in floor mode, it now adds single quotation marks around the route name so it supports spaces in the name.
* Fix altitude hold not functioning consistently while in manual control.
* When in manual control and in atmosphere, lateral engines now work to counter lateral drift.

### Removed
* Command `route-set-all-margins` and `route-set-all-max-speeds` (use `route-set-pos-option`)

## 1.4.0 - 2023-10-08

### Added
* Support for not having engines in all directions.
* Settings for the yaw/pitch/roll controller.
* Middle mouse button button toggle forward thrust when manual controls are active (if `allowForwardToggle` is true)
* Commands `strict-mode` and `free-mode` to easily setup the script for the two supported operational modes.

### Changed
* Significantly quicker start up sequence. Especially noticeable on manually controlled constructs.
* Command `get-all` now lists settings in alphabetical order.
* `yawAlignmentThrustLimiter` now has a default of 3 degrees (was 1).
* Reduced default derivative value of axis controller from 1600 to 1000 on light constructs to reduce jittering seen by some players.

### Fixed
* If a communication channel is set, but receiver or emitter aren't linked, an error is now logged instead of terminating the script.
* Control key once again activates brakes while in manual control.

### Removed
* Fuel gauges on the screen element have been removed to save code space (still available on the HUD).

## 1.3.0 - 2023-09-20

### Added
* New command `position-above` to tell the construct to center and align its position based on two elements.

## 1.2.1 - 2023-09-16

### Fixed
* Modifier keys (shift/alt/ctrl) no longer interfere with manual controls. (bug introduced in 1.2.0)
* HUD layout fixed for different screen resolutions

## 1.2.0 - 2023-09-15

### Added
* Support for using only vertical hover or booster engines (no downward facing regular engines)
* Support for radars

## 1.1.0 - 2023-09-09

### Added
* HUD with fuel gauges.
* Support for rocket boosters.
* New setting `pathAlignmentDistanceLimitFromSurface` that allows you to set a distance from the closest planet/moon surface at which the construct will align topside along path to use main engines for propulsion.

### Changed
* Command `show-widgets` replaced with short-cut `ALT-SHIFT-8`

### Fixed
* When starting a route with skippable points, route legs containing skippable points are now taken into account when starting a route. In other words, you can now start a route while near a skippable point.

## 1.0.0 - 2023-08-24

### Added

### New features
* Added access control that allows the owner of the construct to configure if non-owners are allowed to run certain routes or control the construct manually.
* Added support for a geofence, to prevent the construct from being flown too far away.
* Support to automatically opening and closing doors/gates when activating a route and reaching the final waypoint, respectively. This also works for multi-floor mode.
* Support for two Manual Switches that follow gate state or the state of the remote controller, depending on their name.
* Now supports hover engines and vertical boosters.

### Other additions
* Command `route-set-pos-option` now can toggle gate control for a point in a route.
* New settings
  * `commChannel` for setting the channel to use for gate control
  * `shutdownDelayForGate` for setting the delay to wait for gates to close after landing.
  * `openGateWaitDelay` for setting the delay before starting any movement after opening gates.
  * `openGateMaxDistance` for setting the max distance to a gate control enabled point; further distances causes gates not to be opened on route activation.
  * `setWaypointAlongRoute` which, if enabled, makes the waypoint to be set for the next point in the route.
  * `dockingMode` to control how the construct docks to other constructs of larger core size.
  * `globalMaxSpeed` to set a global max speed. This overrides any route-specific settings and also applies to manual control.
* Commands `move` and `goto` now have a new option `-forceVerticalUp` (default true) that allows you to opt in to aligning to the path by setting this to false.
* Manual control now also accepts Q and E keys for strafing left/right, in addition to the existing ALT+A and ALT+E. (Assuming default key bindings)
* New commands
  * `closest-on-line`, that calculates the closest point on the line that passes through two given positions.
  * For access control
    * `allow-route`
    * `disallow-route`
    * `allowed-routes`
    * `allow-manual-control`
    * `disallow-manual-control`
    * `add-admin`
    * `remove-admin`
    * `add-admin-org`
    * `remove-admin-org`
    * `print-admins`

### Fixed
* Formatting of a few log messages
* Sped up fuel gauges so they show quicker, mostly noticeable on constructs with many elements.
* When holding position, always align up-side along vertical up, i.e. away from the gravity well.
* In manual control, the throttle now properly adjusts the applied acceleration.

### Changed
* Command `route-set-pos-option` now takes a range of indexes, which allows setting options on multiple points at the same time. Use `-ix`and `-endIx` to specify start and end index.
* Major rewrite of alignment handling, splitting pitch and yaw from each other.
* The minimal HUD got even more minimal; removed max speed reported by game which was only a theoretical max speed.
* When deleting a waypoint it now prints the position it held so that you can re-create it if you want to undo the operation.
* Changed speed evaluation for atmospheric entry resulting in a smoother and faster descent.

### Other
* Open Sourced these repositories:
  * A library to communicate with screens and emitters/receivers: https://github.com/PerMalmberg/du-stream
  * Code for gate control: https://github.com/PerMalmberg/du-yfs-gate-control

## 0.2.10 - 2023-06-24

## Fixed
* Further improvements relating to the end points in a route. `create-vertical-route` now sets a 0.3m margin on them by default to reduce the risk of "getting stuck" due to being offset from the route and unable to slide along the floor/ground.

## 0.2.9 - 2023-06-23

## Fixed

* Options, including margin, for the first waypoint in a route was not kept when a route was adjusted during route-activation. For example, this could cause issues taking off, where the elevator would just stand still with vertical engines active without going anywhere. If you have points with non-default margins, these will now be used as intended.

## 0.2.8 - 2023-06-23

### Fixed
* Alignment along the path instead of gravity now works on both intended axes instead of just one.

### Added
* New command: `route-print-pos-options` to print options set on a point in a route.

## 0.2.7 - 2023-06-20

### Fixed
* Auto shutdown fixed (broken by DU 1.4 changes)
* Update to use json.lua lib

## 0.2.6 - 2023-06-18

### Changed
* Mainly noticeable on ships like the Bug and Beetle, drive engines are now kept active when transitioning from vertical to horizontal flight.

## 0.2.5 - 2023-06-11

### Fixed
* If a route has been selected using the command `set -showFloor` and that route does not exist, the an error message is printed and a the regular route selection screen is displayed instead of leaving the screen in "offline" mode.
* Slight formatting fixes in log messages for the `set` command.

### Added
* Variant for The Bug v2.0

## 0.2.4 - 2023-06-04

### Changed
* Implemented a compatibility layer for changes coming in DU 1.4. There is sadly no guarantee this covers everything, time will tell if it is enough.

### Non-user facing changes
* Reduced code size of du-libs by 10kb
* Fixed an issue in the task management system.

## 0.2.3 - 2023-06-01

### Added

* New command `get-parallel-from-route` to ease the creation of parallel routes when using the `create-vertical-route` command.
* New command `sub-pos` that takes one, optionally two, `::pos{}` strings and prints the direction and distance between them (or from the current position if no second argument is given).
* New command `route-rename` to rename a route.

### Fixed

* `goto` and `move` commands now interpret the `-maxspeed` argument as km/h instead m/s, as they were documented to do.
* Activating manual control after using `goto` or `move` commands no longer causes a slight unintentional yaw movement.
* When the ECU is active, CTRL key no longer activates the brakes.

### Changed

* "ECU Active" now displayed in red instead of white.
* Manual yaw control no longer rotates back to where the A/D key was released. Instead, it comes to a stop as soon as possible and remains at whatever direction that is, like what people are used to from other scripts.

## 0.2.2 - 2023-05-27

### Added

* Variant for the Planck

## 0.2.1 - 2023-05-24

## Changed
* Reduced default value of `pathAlignmentAngleLimit` from 40 to 10 degrees.
* Increased default value if `pathAlignmentDistanceLimit` from 100 to 200 meters.

## Fixed
* The issue found in v0.2.0 where it wanted to turn during adjustment before taking off has been fixed.

## 0.2.0 - 2023-05-22

### Changed

### Major changes
* New default behavior: To increase accuracy, the construct now tilts along the flight path. This behavior can be adjusted via the two new settings `pathAlignmentAngleLimit` and `pathAlignmentDistanceLimit`.

### Fixed
* Changing direction mid-route no longer causes overshoots while traveling back to the new start point. This was especially noticeable in vertical movement at high speeds.
* Skippable points were not properly handled during route-activation, causing route activation to fail.

## 0.1.0 - 2023-05-18

### Added

#### Major additions
* New on-screen editor for routes, making it much easier to add/remove/reorder points in a route.
* "Floor"-concept, allowing you to travel not only to the first and last points, but also to any intermediate point in the route. The script will behave the same for the intermediary point as it did with the first/last previously, i.e. if on a ground/floor it will perform the automatic shutdown. A typical use case for this feature is an in-door elevator or a route around your mining units.
  * Each waypoint can be set to be skippable, meaning that it won't be included in the route when determining the path to travel.
  * Each waypoint can be set to be unselectable, meaning that it isn't displayed on the floor-selection screen. As such you can have many points in your route, but only a few are valid as destinations.

#### Minor additions
* Pagination on route selection page
* Up to six routes now shown on route selection page.
* Beneath each route, there is now an icon to show it in floor-mode.
* New setting `-showFloor`
* New command `pos-rename` to rename a waypoint.

### Change
* Change to darker color scheme for the screen for increased readability.
* Route-buttons now show "Start/End" instead of "Beginning/End"
* `pos-save-current-as` now takes two parameters instead of a single name.

### Fixed
* Activating a route while still in movement as the result of manual control input no longer results in the route being aborted once the first point is reached.
* Activating manual control after running a route no longer causes the construct to turn to the last direction used in manual control before route activation.

## 0.0.25 - 2023-04-28
* Added variant for Y-Lift M3 0T XS Beetle v1.0

## 0.0.24 - 2023-04-23

### Fixed
* Version information on details page on screen fixed.

## 0.0.23 - 2023-04-23

### Added
* 10XS Atmospheric only variant.

## 0.0.22 - 2023-04-23

Significant changes has been made to how the script follows a path as well as the setup procedure. Instead of basing the route on the orientation of the construct on which the elevator is parked, the gravity vector of a selected reference elevator is used and the mid point just outside atmosphere is no longer added by default. This makes for faster travel and reduces fuel usage.

In testing, existing routes have been working as expected, but as there are so many variables in play you may have to make adjustments to yours. Creating a new route may, depending on how the earlier reference construct was placed, result in a different endpoint to previously created routes. Specifically, if the reference construct was placed using the snapping feature on another one, its up-direction will have a different direction from the gravity vector. This difference increases with each additional core between the first placed core and the reference core.

> Is your elevator passing through, or is parked in a narrow shaft? If so, you probably should add a waypoint such that the travel path in the shaft becomes aligned to the shaft (and likely the gravity vector too), simply place a waypoint in front of the entrance and add it to the route in the correct order _before upgrading_.

> If you used the old command `create-gravity-route` to create your route you should be unaffected by these changes as your path is already aligned to gravity.

The script now also works well on tiny constructs (commonly known as AWP [Articulating Work Platform] in the community) which opens up for a lot of new applications, such as rescue VTOL vehicles and other fun things.

### Added
* New `align-to-vector` command that can be used to align the elevator to a specific direction, such as the side of a static construct. See instructions in the manual.
* `print-vertical-up` to print the vertical up vector at the current location.

### Changed
* Install procedure changed, there is now only the `create-vertical-route` command.
* New flight path follow algorithm and behavior.
* Small constructs now bobs less.
* Removed the precision-concept from waypoints.
* Command `create-vertical-route` no longer creates a mid point by default. See new instructions in manual.
* Parameter name changes to command `create-vertical-route`
* Default `minimumPathCheckOffset` is now 2m to cater for offsets during accelerations on non-gravity aligned flight paths.

### Removed
* Setting `manualHoldMarginMassThreshold` obsolete and removed.
* Command `create-gravity-route` removed (`create-vertical-route` now does the same thing unless given a custom direction).

### Fixed
* Small adjustment to braking in space flight to prevent overshoot in certain situations.

## 0.0.19 - 2023-04-07

### Added
* Setting `manualHoldMarginMassThreshold` to control the total mass at which the hold margin for manual control is reduced by 75% to reduce oscillations.

## 0.0.18 - 2023-04-06

### Fixed
* Corrected order of link checks at startup to fix a script error when not linked to core.

## 0.0.17 - 2023-04-05

### Fixed
* Fixed reading number settings from an empty data bank.

## 0.0.16 - 2023-04-05

### Added
* 16XS atmospheric engine variant.

## 0.0.15 - 2023-04-05

### Added
* New setting `turnAngle` to set the angle per key press for the WSAD controller.

### Removed
* Command `turn-angle`.

## 0.0.14 - 2023-04-05

### Removed
* Smoothing on start removed, didn't work out quite as desired.

### Changed
* Reworked height monitor for WSAD controller.

## 0.0.13 - 2023-04-04

### Changed
* WSAD controller now levels out vertical movement instead of trying to move back to the height at which the up/down command is canceled.
* Added a smoothing to the acceleration during the first second for easier adjustments.

## 0.0.12 - 2023-04-02

### NOTE
* Requires new screen-code when updating to, or past, this version.

### Changed
* Slight improvement to WASD control in terms of holding position and stopping.
* Reduced engine flicker while maintaining speed in atmosphere (practically only noticeable on tiny ships)
* Improved serialization of data to screen for reduced resource usage.
* ECU now properly shuts down if floor is detected.

### Added
* New commands: `route-move-pos-back` and `route-move-pos-forward`
* Now supports running on an ECU.

## 0.0.11 - 2023-04-01

### Fixed
* Waypoint no longer set when controlling with WSAD.

## 0.0.10 - 2023-04-01

### Added
* Support for setting limits on engine type, size and count. This is to allow selling smaller, purpose built, ships without giving away the entire script for a reduced price.

### Fixed
* Made correction to properly read boolean 'false' from settings.
* Changes to WSAD controller for more reliable key press captures.

### Changed
* Changes to WSAD controller for faster stop.

## 0.0.9 - 2023-03-26

### Changed

* Fixed PID selection for axis control relating to lighter constructs.
* Manual control (WASD, Alt-A/D) controls no longer moves by steps and instead accelerates as longs as the key is held.
* Manual control speed now controlled via mouse scroll wheel.
* `goto` now takes and `offset` option so that it is possible to stop at an offset from the given point. Negative offsets means the other side of the point from where the approach happens.

### Added
* A tiny hud showing target speed and max speed in upper left corner of the screen.
* New setting `-throttleStep` to control step size for manual control
* New setting `-manualControlOnStartup` to make the controller enable manual control on startup.

### Removed
* `speed` command

### Fixed

* `strafe` command no longer turns towards the new position

## 0.0.8 - 2023-03-12

### Changed

* Threshold for triggering precision movement for a path increased to 0.95.
* Path alignment now only checked when moving along a precision path; this makes diagonal movement more smooth (at the cost of less accuracy during the acceleration phase)
* Adjusted low speed control to be a bit more responsive.
* Adjusted roll/yaw/pitch controls to reduce overshoot.

## 0.0.7 - 2023-03-11

### Changed

* Refactored alignment functions.

## 0.0.6 - 2023-03-09

### Changed

* Route data bank is now expected to be named "Routes"

### Added

* And optional data bank named "Settings" is supported. If not present, it falls back to the route data bank.


## x.y.z - 2023-xx-xx

# Changed

# Added

# Fixed

# Removed

