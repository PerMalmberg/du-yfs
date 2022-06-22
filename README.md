# Todo

* Space flight - center of planet as reference instead of GAlongGravity?
    * Brakes in space - GAlongGravity returns nil? Use custom reference from the closest planet instead
* Turning - make new path based on current pos and direction.
* Diagonal movement.

# Brakes

- The value we now get is for both, we just must adjust it for atmo.
  Does enabling brakes cause up/down movement? They do!

# Cross and dot

Right hand rule for cross product:

* Point right flat hand in direction of first arrow
* Curl fingers in direction of second.
* Thumb now point in direction of the resulting third arrow.

  a.b = 0 when vectors are orthogonal.
  a.b = 1 when vectors are parallel.
  axb = 0 when vectors are parallel.