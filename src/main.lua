local FlightCore = require("FlightCore")
local universe = require("universe/Universe")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")
local moveControl = require("movement/MoveControl")()
local StandardMovement = require("movement/StandardMovement")

local fc = FlightCore()

--local testPos = universe:ParsePosition("::pos{0,2,7.6926,78.1056,60}")

local upDirection = -construct.orientation.AlongGravity()
local forwardDirection = construct.orientation.Forward()
local rightDirection = construct.orientation.Right()
local startPos = construct.position.Current()

fc:ReceiveEvents()

function AddPath(origin, destination, maxSpeed, initialMargin, finalMargin)
    -- Start point of path

    local toAdd = {}

    local current = destination
    local m = 0
    local backwards = (origin - destination):normalize()

    -- Create waypoints from destination going backwards towards origin but not past the origin
    while m < initialMargin and (current - destination):len2() <= (origin - destination):len2() do
        m = m + finalMargin -- Increase margin for each point
        local before = current + backwards * m
        table.insert(toAdd, 1, StandardMovement(before, current, m, maxSpeed))

        current = before
    end

    for i, v in ipairs(toAdd) do
        if i == #toAdd then
            v.reachStandStill = true
        end
        moveControl:Append(v)
    end
end

function ActionStart(system, key)
    if key == "option1" then
        --moveControl:Append(StandardMovement(construct.position.Current(), startPos + upDirection * 150, 0.1, calc.Kph2Mps(20)))
        --moveControl:Append(StandardMovement(startPos + upDirection * 150, startPos + upDirection * 30 + forwardDirection * 30 + rightDirection * 30, 0.1, calc.Kph2Mps(5)))
        --moveControl:Append(StandardMovement(startPos + upDirection * 30 + forwardDirection * 30 + rightDirection * 30, startPos + upDirection * 10, 0.1, calc.Kph2Mps(5)))
        --moveControl:Append(StandardMovement(startPos + upDirection * 10, startPos, 0.1, calc.Kph2Mps(5)))
        moveControl:Clear()
        AddPath(startPos, startPos + upDirection * 150, calc.Kph2Mps(20), 3, 0.1)
        AddPath(startPos + upDirection * 150, startPos + upDirection * 30 + forwardDirection * 30 + rightDirection * 30, calc.Kph2Mps(20), 3, 0.1)
        AddPath(startPos + upDirection * 30 + forwardDirection * 30 + rightDirection * 30, startPos + upDirection * 10, calc.Kph2Mps(20), 3, 0.1)
        AddPath(startPos + upDirection * 10, startPos, calc.Kph2Mps(5), 3, 0.1)
    elseif key == "option2" then
        moveControl:Clear()
        moveControl:Append(StandardMovement(construct.position.Current(), startPos + upDirection * 1, 0.1, calc.Kph2Mps(20)))
    elseif key == "option3" then
        moveControl:Clear()

        moveControl:Append(StandardMovement(construct.position.Current(), startPos + upDirection * 20 + forwardDirection * 10 + rightDirection * 10, 0.1, calc.Kph2Mps(3)))
    elseif key == "option9" then
        moveControl:Clear()
        moveControl:Append(StandardMovement(construct.position.Current(), construct.position.Current(), 0.1, calc.Kph2Mps(10)))
    elseif key == "brake" then
        moveControl:SetBrake(true)
        system.print("Enabled brakes")
    end
end

function ActionStop(system, key)
    if key == "brake" then
        moveControl:SetBrake(false)
        system.print("Diasbled brakes")
    end
end

function ActionLoop(system, key)
end

system:onEvent("actionStart", ActionStart)
system:onEvent("actionLoop", ActionLoop)
system:onEvent("actionStop", ActionStop)
