# YFS Changelog

All notable changes to this project will be documented in this file. The version number refers to the version printed in Lua chat for the control unit/ECU, not the one displayed on the screen in offline mode.

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

