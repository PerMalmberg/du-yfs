local library = require("du-libs:abstraction/Library")()
local vehicle = require("du-libs:abstraction/Vehicle")()
local fc = require("flight/FlightCore")()
local calc = require("du-libs:util/Calc")
local brakes = require("flight/Brakes")()
local input = require("du-libs:input/Input")()
local Criteria = require("du-libs:input/Criteria")
local keys = require("du-libs:input/Keys")
local log = require("du-libs:debug/Log")()
local cmd = require("du-libs:commandline/CommandLine")()
local utils = require("cpml/utils")
local universe = require("du-libs:universe/Universe")()
local PointOptions = require("flight/route/PointOptions")
local abs = math.abs

local brakeLight = library:GetLinkByName("brakelight")

fc:ReceiveEvents()

local routeController = fc:GetRoutController()

local function Update(system)
    if brakeLight ~= nil then
        if brakes:IsEngaged() then
            brakeLight.activate()
        else
            brakeLight.deactivate()
        end
    end
end
system:onEvent("onUpdate", Update)

input:Register(keys.option1, Criteria():LAlt():OnPress(), function()
    if player.isFrozen() == 1 then
        player.freeze(0)
        log:Info("Automatic mode")
    else
        player.freeze(1)
        log:Info("Manual mode")
    end
end)

local step = 50
local speed = 150

local function move(reference, distance)
    routeController:ActivateRoute()
    local route = routeController:CurrentRoute()
    local opt = route:AddCoordinate(vehicle.position.Current() + reference * distance):Options()
    opt:Set(PointOptions.MAX_SPEED, calc.Kph2Mps(speed))

    fc:StartFlight()
end

input:Register(keys.forward, Criteria():OnRepeat(), function()
    move(vehicle.orientation.Forward(), step)
end)

input:Register(keys.backward, Criteria():OnRepeat(), function()
    move(vehicle.orientation.Forward(), -step)
end)

input:Register(keys.strafeleft, Criteria():OnRepeat(), function()
    move(-vehicle.orientation.Right(), step)
end)

input:Register(keys.straferight, Criteria():OnRepeat(), function()
    move(vehicle.orientation.Right(), step)
end)

input:Register(keys.up, Criteria():OnRepeat(), function()
    move(-universe:VerticalReferenceVector(), step)
end)

input:Register(keys.down, Criteria():OnRepeat(), function()
    move(-universe:VerticalReferenceVector(), -step)
end)

input:Register(keys.yawleft, Criteria():OnRepeat(), function()
    fc:Turn(1, vehicle.orientation.Up())
end)

input:Register(keys.yawright, Criteria():OnRepeat(), function()
    fc:Turn(-1, vehicle.orientation.Up(), vehicle.position.Current())
end)

input:Register(keys.brake, Criteria():OnPress(), function()
    brakes:Forced(true)
end)

input:Register(keys.brake, Criteria():OnRelease(), function()
    brakes:Forced(false)
end)

local start = vehicle.position.Current()

input:Register(keys.option7, Criteria():OnPress(), function()
    routeController:ActivateRoute()
    local route = routeController:CurrentRoute()
    local opt = route:AddPos("::pos{0,2,7.7063,78.0886,39.7209}"):Options()
    opt:Set(PointOptions.MAX_SPEED, calc.Kph2Mps(40))
    opt:Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():unpack() })

    opt = route:AddPos("::pos{0,2,7.7097,78.0763,38.9275}"):Options()
    opt:Set(PointOptions.MAX_SPEED, calc.Kph2Mps(100))
    opt:Set(PointOptions.MARGIN, 1)

    opt = route:AddPos("::pos{0,2,7.6924,78.0694,36.1659}"):Options()
    fc:StartFlight()
end)

input:Register(keys.option8, Criteria():OnPress(), function()
    routeController:ActivateRoute()
    local route = routeController:CurrentRoute()

    route:AddCoordinate(start - universe:VerticalReferenceVector() * 2)
    route:AddCoordinate(start - universe:VerticalReferenceVector() * 100)

    fc:StartFlight()
end)

input:Register(keys.option9, Criteria():OnPress(), function()
    routeController:ActivateRoute()
    local route = routeController:CurrentRoute()
    route:AddCoordinate(start)

    fc:StartFlight()
end)

local stepFunc = function(data)
    step = utils.clamp(data.commandValue, 0.1, 20000)
    log:Info("Step set to:", step)
end

cmd:Accept("step", stepFunc):AsNumber():Mandatory()

local speedFunc = function(data)
    speed = utils.clamp(data.commandValue, 1, 2000)
    log:Info("Speed set to:", speed)
end

cmd:Accept("speed", speedFunc):AsNumber():Mandatory()

local moveFunc = function(data)
    routeController:ActivateRoute()
    local route = routeController:CurrentRoute()
    local pos = vehicle.position.Current()
    data.v = math.abs(data.v)
    local opt = route:AddCoordinate(pos + vehicle.orientation.Forward() * data.f + vehicle.orientation.Right() * data.r - universe:VerticalReferenceVector() * data.u):Options()
    opt:Set(PointOptions.MAX_SPEED, calc.Kph2Mps(data.v))

    fc:StartFlight()
end

local moveCmd = cmd:Accept("move", moveFunc):AsString()
moveCmd:Option("-f"):AsNumber():Mandatory():Default(0)
moveCmd:Option("-u"):AsNumber():Mandatory():Default(0)
moveCmd:Option("-r"):AsNumber():Mandatory():Default(0)
moveCmd:Option("-v"):AsNumber():Mandatory():Default(10)

local turnFunc = function(data)
    -- Turn in the expected way, i.e. clockwise on positive values.
    local angle = -data.commandValue

    fc:Turn(angle, vehicle.orientation.Up(), vehicle.position.Current())
end

cmd:Accept("turn", turnFunc):AsNumber()

local strafeFunc = function(data)
    routeController:ActivateRoute()
    local route = routeController:CurrentRoute()
    local opt = route:AddCoordinate(vehicle.position.Current() + vehicle.orientation.Right() * data.commandValue):Options()
    opt:Set(PointOptions.MAX_SPEED, calc.Kph2Mps(abs(data.v)))
    opt:Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():unpack() })

    fc:StartFlight()
end

local strafeCmd = cmd:Accept("strafe", strafeFunc):AsNumber()
strafeCmd:Option("-v"):AsNumber():Mandatory():Default(10)

local listRoutes = function(data)
    local routes = routeController:GetRouteNames()
    log:Info(#routes, " available routes")
    for _, r in ipairs(routes) do
        log:Info(r)
    end
end

cmd:Accept("route-list", listRoutes):AsString()

local loadRoute = function(data)
    routeController:LoadRoute(data.commandValue)
end

cmd:Accept("route-load", loadRoute):AsString()

local createRoute = function(data)
    routeController:CreateRoute(data.commandValue)
end

cmd:Accept("route-create", createRoute):AsString():Mandatory()

local routeSave = function(data)
    routeController:SaveRoute()
end

cmd:Accept("route-save", routeSave):AsString()

local deleteRoute = function(data)
    routeController:DeleteRoute(data.commandValue)
end

cmd :Accept("route-activate", function(data)
    if routeController:ActivateRoute(data.commandValue) then
        fc:StartFlight()
    end
end):AsString():Mandatory()

cmd:Accept("route-delete", deleteRoute):AsString()

local function addPointOptions(c)
    c:Option("-precision"):AsBoolean():Default(false)
    c:Option("-lockdir"):AsBoolean():Default(false)
    c:Option("-maxspeed"):AsNumber():Mandatory()
    c:Option("-margin"):AsNumber():Default(0.1)
end

local function createOptions(data)
    local opt = PointOptions:New()
    opt:Set(PointOptions.PRECISION, data.precision)
    opt:Set(PointOptions.MAX_SPEED, data.maxspeed)
    opt:Set(PointOptions.MARGIN, data.margin)

    if data.lockdir then
        opt:Set(PointOptions.LOCK_DIRECTION, { vehicle.orientation.Forward():unpack() })
    end
    return opt
end

local addCurrentPos = function(data)
    local route = routeController:CurrentEdit()

    if not route then
        log:Error("No route open for edit")
        return
    end

    local point = route:AddCurrentPos()
    point.options = createOptions(data)
end

local addCurrentToRoute = cmd:Accept("route-add-current-pos", addCurrentPos):AsString()
addPointOptions(addCurrentToRoute)

local addNamedPos = function(data)
    local ref = routeController:LoadWaypoint(data.commandValue)

    if ref then
        local route = routeController:CurrentEdit()
        local p = route:AddWaypointRef(data.commandValue)
        p.options = createOptions(data)
    end
end

local addStoredToRoute = cmd:Accept("route-add-named-pos", addNamedPos):AsString()
addPointOptions(addStoredToRoute)

local saveAsWaypoint = function(data)
    local pos = universe:CreatePos(vehicle.position.Current()):AsPosString()
    routeController:StoreWaypoint(data.commandValue, pos, createOptions(data))
end

local saveCurrentPosAs = cmd:Accept("save-position-as", saveAsWaypoint):AsString():Mandatory()
addPointOptions(saveCurrentPosAs)

cmd :Accept("route-dump", function(data)
    local r = routeController:CurrentEdit()
    if r then
        r:Dump()
    end
end):AsString()