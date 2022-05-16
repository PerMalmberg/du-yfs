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
local parallelPathStart = startPos + calc.StraightForward(upDirection, construct.orientation.Right()) * 10 -- 10m infront

fc:ReceiveEvents()

function ActionStart(system, key)
    if key == "option1" then
        moveControl:Clear()
        moveControl:Append(StandardMovement(construct.position.Current(), startPos + upDirection * 1050, 0.1, calc.Kph2Mps(100)))
    elseif key == "option2" then
        moveControl:Clear()
        moveControl:Append(StandardMovement(construct.position.Current(), startPos + upDirection * 1, 0.1, calc.Kph2Mps(50)))
    elseif key == "option3" then
        moveControl:Clear()

        moveControl:Append(StandardMovement(construct.position.Current(), startPos + upDirection * 20 + forwardDirection * 10 + rightDirection * 10, 0.1, calc.Kph2Mps(3)))
    elseif key == "option9" then
        moveControl:Clear()
        moveControl:Append(StandardMovement(construct.position.Current(), construct.position.Current(), 0.1, calc.Kph2Mps(10)))
    end
end

system:onEvent("actionStart", ActionStart)
