# Todo

Currently FlightCore updated the waypoints when reached. This causes the state to never see that it has reached the
waypoint and thus can't act on it. Should the state request the next waypoint to be activated or should there be an
event when the waypoint is reached (maybe with info if it is the last state?)

# Brakes

Does enabling brakes cause up/down movement? They do!

# Cross and dot

Right hand rule for cross product:

* Point right flat hand in direction of first arrow
* Curl fingers in direction of second.
* Thumb now point in direction of the resulting third arrow.

  a.b = 0 when vectors are orthogonal.
  a.b = 1 when vectors are parallel.
  axb = 0 when vectors are parallel.