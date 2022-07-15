# Todo

* Alternating between ApproachWaypoint and CorrectDeviation/ReturnToPath results in not enough brake.
* Loading/Saving route untested
* Add unit tests for route point
* Add unit tests for point options
* Add unit tests for route
* Add unit tests for route controller
* Can we float down on brakes instead of using engines to counter acceleration?

# Brakes

- Does enabling brakes cause up/down movement? They do!

# Flight

```mermaid
flowchart TD
  Idle-->Travel
  ApprochingLast{last waypoint}
  ApproachWaypoint -- out of alignment --> CorrectDeviation
  ApproachWaypoint -- dist < brakeDist && dist > 1000 --> Travel
  ApproachWaypoint -- waypoint reached --> ApprochingLast
  ApprochingLast -- Yes --> Hold
  ApprochingLast -- No --> Travel
  CorrectDeviation -- speed < limit --> ReturnToPath
  ReturnToPath -- distance < margin --> Travel
  Travel -- need to brake -->ApproachWaypoint
  Travel -- out of alignment --> CorrectDeviation
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