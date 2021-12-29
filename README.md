# Y Flight Core

# Goals
- Engine control
- Pitch control
- Yaw control
- Roll control
- Break control
- Event driven
- Publish data

## Code standard

- Go-like

## API

## Type `EngineGroup`

Engine groups are custom groups of tags for passing around to other engine APIs.

- add(name)
- remove(name)
- union() - Get tag list for union.
- intersection() - Get tag list for intersection.

## Type `Degrees`

- Contains an angle in degrees.

## Type `Radians`

 - Contains an angle in radians

## Type `Acceleration`

- Contains an acceleration in m/s<sup>2</sup>

## Constants

- RollAxle - `vec3(0, 1, 0)`
- PitchAxle - `vec3(1, 0, 0)`
- YawAxle - `vec3(0, 0, 1)`
- Forward - `vec3(0, 1, 0)`
- Right - `vec3(1, 0, 0)`
- Up - `vec3(0, 0, 1)`

## Type `FlightCore`

- Roll(angle `Degrees|Radians`)
- Pitch(angle `Degrees|Radians`)
- Yaw(angle `Degrees|Radians`)
- AlignAwayFromGravity() - aligns the core's up direction to point 180 degrees away from the direction of gravity.
- Hover() - sets the power of the engines such that the construct hovers stationary at the current position.
- MoveInDirection(direction `vec3`, acceleration `Acceleration`)