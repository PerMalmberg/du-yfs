# YFS Changelog

All notable changes to this project will be documented in this file.

## 0.0.9 - 2023-03-xx

### Changed

* Fixed PID selection for axis control relating to lighter constructs.
* Manual control (WASD, Alt-A/D) controls no longer moves by steps and instead accelerates as longs as the key is held.
* Manual control speed now controlled via mouse scroll wheel.
* Removed speed command
* `goto` now takes and `offset` option so that it is possible to stop at an offset from the given point. Negative offsets means the other side of the point from where the approach happens.

### Fixed

* 'strafe' command no longer turns towards the new position

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

