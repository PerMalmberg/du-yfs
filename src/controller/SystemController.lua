local Container          = require("element/Container")
local ContainerTalents   = require("element/ContainerTalents")
local ControlCommands    = require("controller/ControlCommands")
local Stopwatch          = require("system/Stopwatch")
local Task               = require("system/Task")
local ValueTree          = require("util/ValueTree")
local InfoCentral        = require("info/InfoCentral")
local floorDetector      = require("controller/FloorDetector").Instance()
local log                = require("debug/Log")()
local commandLine        = require("commandline/CommandLine").Instance()
local pub                = require("util/PubSub").Instance()
local input              = require("input/Input").Instance()
local Vec2               = require("native/Vec2")
local layout             = require("screen/layout")
local Stream             = require("Stream")
local calc               = require("util/Calc")
local su                 = require("util/StringUtil")
local max                = math.max
local min                = math.min
local distanceFormat     = require("util/DistanceFormat")
local massFormat         = require("util/MassFormat")
local TotalMass          = require("abstraction/Vehicle").New().mass.Total

---@class SystemController

local SystemController   = {}
SystemController.__index = SystemController

---@param flightCore FlightCore
---@param settings Settings
---@return SystemController
function SystemController.New(flightCore, settings)
    local s = {}
    local layoutSent = false
    local commands = ControlCommands.New(input, commandLine, flightCore)
    local info = InfoCentral.Instance()
    local rc = flightCore.GetRouteController()
    local dataToScreen = ValueTree.New()
    local talents = ContainerTalents.New(0, 0, 0, 0, 0, 0)
    local routePage = 1
    local routesPerPage = 5
    local waypointPage = 1
    local waypointsPerPage = 10

    local stream ---@type Stream -- forward declared

    local routeEditorPrefix = "#re-"

    local editRouteIndex = 1
    local editRoutePointsPerPage = 10

    local editPointPage = 1
    pub.RegisterBool("RouteOpenedForEdit", function(_, _)
        editPointPage = 1
    end)

    ---@param cmd string
    function s.runRouteEditorCommand(cmd)
        if cmd == "previous-route" then
            editRouteIndex = max(1, editRouteIndex - 1)
        elseif cmd == "next-route" then
            editRouteIndex = min(#rc.GetRouteNames(), editRouteIndex + 1)
        elseif cmd == "prev-point-page" then
            local r = rc.CurrentEdit()
            if r then
                editPointPage = max(1, editPointPage - 1)
            end
        elseif cmd == "next-point-page" then
            local r = rc.CurrentEdit()
            if r then
                editPointPage = min(editPointPage + 1, r.GetPageCount(editRoutePointsPerPage))
            end
        elseif cmd == "prev-wp-page" then
            waypointPage = max(1, waypointPage - 1)
        elseif cmd == "next-wp-page" then
            waypointPage = min(waypointPage + 1, rc.GetWaypointPages(waypointsPerPage))
        end

        s.updateEditRouteData()
    end

    function s.dataReceived(data)
        -- Publish data to system
        if data == nil then return end
        local command = data["mouse_click"]
        if command ~= nil then
            if su.StartsWith(command, routeEditorPrefix) then
                command = su.RemovePrefix(command, routeEditorPrefix)
                s.runRouteEditorCommand(command)
            else
                commandLine.Exec(command)
            end

            s.updateEditRouteData()
        end
    end

    local function sendRoutes()
        local route = {}
        for i, r in ipairs(rc.GetRoutePage(routePage, routesPerPage)) do
            route[tostring(i)] = { visible = true, name = r }
        end

        -- Ensure to hide the rest if routes have been removed.
        for i = TableLen(route) + 1, routesPerPage, 1 do
            route[tostring(i)] = { visible = false, name = "" }
        end

        dataToScreen.Set("route", route)
    end

    function s.updateEditRouteData()
        local editRoute = {
            selectRouteName = "",
            routeName = "",
            points = {}
        }

        local routeNames = rc.GetRouteNames()
        if #routeNames > 0 then
            editRoute.selectRouteName = routeNames[editRouteIndex]
        end

        local editing = rc.CurrentEdit()
        local pointsShown = 0

        if editing then
            editRoute.name = rc.CurrentEditName()
            local points = editing.GetPointPage(editPointPage, editRoutePointsPerPage)
            pointsShown = #points

            for index, p in ipairs(points) do
                local pointInfo = {
                    visible = true,
                    index = index + (editPointPage - 1) * editRoutePointsPerPage,
                    position = p.Pos()
                }

                if p.HasWaypointRef() then
                    pointInfo.pointName = p.WaypointRef()
                else
                    pointInfo.pointName = "Anonymous pos."
                end

                editRoute.points[tostring(index)] = pointInfo
            end
        else
            editRoute.name = "-"
        end

        -- Clear old data
        for i = pointsShown + 1, editRoutePointsPerPage, 1 do
            editRoute.points[tostring(i)] = { visible = false }
        end

        dataToScreen.Set("editRoute", editRoute)

        local availableWaypoints = {}

        local waypoints = rc.GetWaypointPage(waypointPage, waypointsPerPage)
        for index, p in ipairs(waypoints) do
            availableWaypoints[tostring(index)] = {
                visible = true,
                name = p.name,
                pos = p.point.Pos()
            }
        end

        for i = #waypoints + 1, waypointsPerPage, 1 do
            availableWaypoints[tostring(i)] = { visible = false }
        end

        dataToScreen.Set("availableWaypoints", availableWaypoints)
    end

    ---@param isTimedOut boolean
    ---@param stream Stream
    local function onTimeout(isTimedOut, stream)
        if isTimedOut then
            layoutSent = false
        elseif not layoutSent then
            stream.Write({ screen_layout = layout })
            stream.Write({ activate_page = "routeSelection" })
            sendRoutes()
            layoutSent = true
        end
    end

    local function screenTask()
        local screen = library.getLinkByClass("ScreenUnit")

        if not screen then return end
        log:Info("Screen found")
        screen.activate()

        local routeTimer = Stopwatch.New()
        routeTimer.Start()

        pub.RegisterTable("FlightData",
            ---@param _ string
            ---@param data FlightData
            function(_, data)
                dataToScreen.Set("flightData/absSpeed", calc.Mps2Kph(data.absSpeed))
                local formatted = distanceFormat(data.waypointDist)
                dataToScreen.Set("nextWp/distance", formatted.value)
                dataToScreen.Set("nextWp/distanceUnit", formatted.unit)

                formatted = massFormat(TotalMass())
                dataToScreen.Set("mass/total", formatted.value)
                dataToScreen.Set("mass/totalUnit", formatted.unit)
            end)

        pub.RegisterTable("RouteData",
            ---@param _ string
            ---@param data {remaining:RouteRemainingInfo, activeRouteName:string|nil}
            function(_, data)
                local formatted = distanceFormat(data.remaining.TotalDistance)
                dataToScreen.Set("finalWp/distance", formatted.value)
                dataToScreen.Set("finalWp/distanceUnit", formatted.unit)
                dataToScreen.Set("route/current/name", data.activeRouteName)
            end)

        pub.RegisterTable("AdjustmentData",
            ---@param _ string
            ---@param data AdjustmentData
            function(_, data)
                dataToScreen.Set("deviation/distance", data.distance)
            end)

        pub.RegisterTable("FloorMonitor",
            ---@param _ string
            ---@param value TelemeterResult
            function(_, value)
                local floor = string.format("Hit: %s, distance: %0.2f, limit: %0.2f",
                    tostring(value.Hit), value.Distance,
                    settings.Get("autoShutdownFloorDistance"))
                dataToScreen.Set("floor", floor)
            end)

        stream = Stream.New(screen, s.dataReceived, 1, onTimeout)

        while screen do
            coroutine.yield()
            stream.Tick()

            if not stream.WaitingToSend() then
                if not routeTimer.IsRunning() or routeTimer.Elapsed() > 2 then
                    sendRoutes()
                    s.updateEditRouteData()
                    routeTimer.Restart()
                end

                -- Get data to send to screen
                local data = dataToScreen.Pick()
                -- Send data to screen
                if data then
                    stream.Write(data)
                else
                    stream.Write('{"keepalive": ""}')
                end
            end
        end
    end

    -- Create a Task to handle communication with the screen
    Task.New("ControllScreen", screenTask)
        .Then(function(...)
            log:Info("No screen connected")
        end).Catch(function(t)
        log:Error(t.Name(), t.Error())
    end)

    settings.RegisterCallback("containerProficiency", function(value)
        talents.ContainerProficiency = value
    end)

    settings.RegisterCallback("fuelTankOptimization", function(value)
        talents.FuelTankOptimization = value
    end)

    settings.RegisterCallback("containerOptimization", function(value)
        talents.ContainerOptimization = value
    end)


    settings.RegisterCallback("atmoFuelTankHandling", function(value)
        talents.AtmoFuelTankHandling = value
    end)


    settings.RegisterCallback("spaceFuelTankHandling", function(value)
        talents.SpaceFuelTankHandling = value
    end)


    settings.RegisterCallback("rocketFuelTankHandling", function(value)
        talents.RocketFuelTankHandling = value
    end)

    Task.New("FuelMonitor", function()
        local sw = Stopwatch.New()
        sw.Start()

        local tanks = {
            atmo = Container.GetAllCo(ContainerType.Atmospheric),
            space = Container.GetAllCo(ContainerType.Space),
            rocket = Container.GetAllCo(ContainerType.Rocket)
        }

        while true do
            if sw.IsRunning() and sw.Elapsed() < 2 then
                coroutine.yield()
            else
                for fuelType, containers in pairs(tanks) do
                    local fillFactors = {} ---@type {name:string, factorBar:Vec2, percent:number, visible:boolean}[]
                    for _, tank in ipairs(containers) do
                        local factor = tank.FuelFillFactor(talents)
                        table.insert(fillFactors,
                            {
                                name = tank.Name(),
                                factorBar = Vec2.New(1, factor),
                                percent = factor * 100,
                                visible = true
                            })
                        coroutine.yield()
                    end

                    -- Sort tanks in acending fuel levels
                    table.sort(fillFactors,
                        function(a, b) return a.percent < b.percent end)

                    for i, tankInfo in ipairs(fillFactors) do
                        dataToScreen.Set(string.format("fuel/%s/%d", fuelType, i), tankInfo)
                    end

                    coroutine.yield()
                end

                sw.Restart()
            end
        end
    end).Then(function(...)
        log:Info("No fuel tanks detected")
    end).Catch(function(t)
        log:Error(t.Name(), t.Error())
    end)

    Task.New("FloorMonitor", function()
        if floorDetector.Present() then
            log:Info("FloorMonitor started")
            local sw = Stopwatch.New()
            sw.Start()

            while true do
                coroutine.yield()
                if sw.Elapsed() > 0.3 then
                    sw.Restart()
                    pub.Publish("FloorMonitor", floorDetector.Measure())
                end
            end
        end
    end).Then(function(...)
        log:Info("Auto shutdown disabled")
    end).Catch(function(t)
        log:Error(t.Name(), t.Error())
    end)

    local show = settings.Get("showWidgetsOnStart", false)
    if show == true or show == 1 then
        pub.Publish("ShowInfoWidgets", true)
    end

    return setmetatable(s, SystemController)
end

return SystemController
