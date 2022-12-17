---@alias BrakeData {maxDeceleration:number, currentDeceleration:number, pid:number}

---@alias FlightData {targetSpeed:number, targetSpeedReason:string, finalSpeed:number, finalSpeedDistance:number, distanceToAtmo:number, dzSpeedInc:number, atmoDistance:number, brakeMaxSpeed:number, waypointDist:number, speedDiff:number, pid:number, fsmState:string, acceleration:number, controlAcc:number, absSpeed:number}
---@alias AdjustmentData {towards:boolean, distance:number, brakeDist:number, speed:number, acceleration:number}
---@alias AxisControlData {angle:number, speed:number, acceleration:number, offset:number}
