# Todo

* Make settings separate commands to make them type safe.
* Stuck on pad on activation - wants to move to first point? Move upwards a little first
* Use PID for adjustment
* Offline screen - make Y white
* EM Stop button
* Overload warning based on setting.
* Changing route in transit, lock dir to new waypoint during return-to-path (if same route?)

* More natural manual control
* Fix overshoot when turning
* Optionally follow waypoints as beizer curves

# Future commands

* orbit-position - height X -radius Y -point inwards/outwards/front/back

# FAQ

- Q: For up-and-over parking, how much above the floor of the space core must the construct enter?
- A: 10m, high enough that it is not caught by the gravity well of the space construct and goes out of the well before trying to come to a stop at the first point when leaving a platform.

- Q: It accelerates, then brakes when taking off
- A: Too heavy load, brake calculations say max 0 km/h.

## Screens

### Take me there
- List of routes
  - Favorites listed first
- Select route, display info.
- Separate button to start route.
- Emergency stop button - Hold postion

### Travel screen
- Emergency stop button - hold position / zero speed limit?
- Leg x of y
- Fuel
- Mass
  - Cargo

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