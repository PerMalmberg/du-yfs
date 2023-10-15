local Stopwatch = require("system/Stopwatch")
require("abstraction/Vehicle")
local Task               = require("system/Task")
local ValueTree          = require("util/ValueTree")
local Vec3               = require("math/Vec3")
local PointOptions       = require("flight/route/PointOptions")
local log                = require("debug/Log").Instance()
local commandLine        = require("commandline/CommandLine").Instance()
local pub                = require("util/PubSub").Instance()
local layout             = require("screen/layout_out")
local Stream             = require("Stream")
local ScreenDevice       = require("device/ScreenDevice")
local calc               = require("util/Calc")
local pagination         = require("util/Pagination")
local distanceFormat     = require("util/DistanceFormat")
local massFormat         = require("util/MassFormat")
local su                 = require("util/StringUtil")
local max                = math.max
local min                = math.min

---@class ScreenController
---@field ActivateFloorMode fun(string):boolean

local ScreenController   = {}
ScreenController.__index = ScreenController

---@param flightCore FlightCore
---@param settings Settings
---@return ScreenController
function ScreenController.New(flightCore, settings)
    local s = {}
    local layoutSent = false

    local rc = flightCore.GetRouteController()
    local dataToScreen = ValueTree.New()
    local routePage = 1
    local routesPerPage = 6

    local waypointPage = 1
    local waypointsPerPage = 10

    local floorPage = 1
    local floorPointsPerPage = 24

    local stream ---@type Stream -- forward declared

    local routeEditorPrefix = "#re-"
    local routeSelectionPrefix = "#rsel-"
    local floorSelectionPrefix = "#fl-"

    local editRouteIndex = 1
    local editRoutePointsPerPage = 10

    local editPointPage = 1
    pub.RegisterBool("RouteOpenedForEdit", function(_, _)
        editPointPage = 1
    end)

    function s.OnData(data)
        -- Publish data to system
        if data == nil then return end
        local command = data["mouse_click"]
        if command ~= nil then
            if su.StartsWith(command, routeEditorPrefix) then
                s.runRouteEditorCommand(su.RemovePrefix(command, routeEditorPrefix))
            elseif su.StartsWith(command, routeSelectionPrefix) then
                s.runRouteSelectionCommand(su.RemovePrefix(command, routeSelectionPrefix))
            elseif su.StartsWith(command, floorSelectionPrefix) then
                s.runFloorSelectionCommand(su.RemovePrefix(command, floorSelectionPrefix))
            else
                commandLine.Exec(command)
                s.updateFloorData()
                s.updateEditRouteData()
                s.sendRoutes()
            end
        end
    end

    ---@param isTimedOut boolean
    ---@param stream Stream
    function s.OnTimeout(isTimedOut, stream)
        if isTimedOut then
            layoutSent = false
        elseif not layoutSent then
            stream.Write({ screen_layout = layout })

            local floorRoute = settings.String("showFloor")
            local floorActivated = false

            if floorRoute ~= "-" then
                floorActivated = s.ActivateFloorMode(floorRoute)
                if not floorActivated then
                    log.Error("Could not activate floor mode")
                end
            end

            if not floorActivated then
                stream.Write({ activate_page = "status,routeSelection" })
            end

            s.sendRoutes()
            layoutSent = true
        end
    end

    function s.RegisterStream(stream)

    end

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

    ---@param cmd string
    function s.runRouteSelectionCommand(cmd)
        if cmd == "next-route-page" then
            routePage = min(routePage + 1, rc.GetPageCount(routesPerPage))
        elseif cmd == "prev-route-page" then
            routePage = max(1, routePage - 1)
        end
        s.sendRoutes()
    end

    ---@param cmd string
    function s.runFloorSelectionCommand(cmd)
        if cmd == "next-floor-page" then
            floorPage = min(floorPage + 1, pagination.GetPageCount(rc.SelectableFloorPoints(), floorPointsPerPage))
        elseif cmd == "prev-floor-page" then
            floorPage = max(1, floorPage - 1)
        end
        s.updateFloorData()
    end

    function s.sendRoutes()
        local routeSelection = {
            routePage = routePage,
            pageCount = rc.GetPageCount(routesPerPage),
            routes = {}
        }
        for i, r in ipairs(rc.GetRoutePage(routePage, routesPerPage)) do
            routeSelection.routes[tostring(i)] = { visible = true, name = r }
        end

        -- Ensure to hide the rest if routes have been removed.
        for i = TableLen(routeSelection.routes) + 1, routesPerPage, 1 do
            routeSelection.routes[tostring(i)] = { visible = false, name = "" }
        end

        dataToScreen.Set("routeSelection", routeSelection)
    end

    function s.updateEditRouteData()
        local routeNames = rc.GetRouteNames()
        local editRoute = {
            ix = editRouteIndex,
            count = #routeNames,
            currentPage = editPointPage,
            pageCount = editPointPage,
            selectRouteName = "",
            routeName = "",
            points = {}
        }

        if #routeNames > 0 then
            editRoute.selectRouteName = routeNames[editRouteIndex]
        end

        local editing = rc.CurrentEdit()
        local pointsShown = 0

        if editing then
            editRoute.name = rc.CurrentEditName()
            editRoute.pageCount = editing.GetPageCount(editRoutePointsPerPage)
            local points = editing.GetPointPage(editPointPage, editRoutePointsPerPage)
            pointsShown = #points
            local distances = rc.CalculateDistances(points)

            for index, p in ipairs(points) do
                local opt = p.Options()
                local gate = opt.Get(PointOptions.GATE, false)
                local skippable = opt.Get(PointOptions.SKIPPABLE, false)
                local selectable = opt.Get(PointOptions.SELECTABLE, true)

                local pointInfo = {
                    visible = true,
                    index = index + (editPointPage - 1) * editRoutePointsPerPage,
                    position = p.Pos(),
                    gate = gate,
                    notGate = not gate,
                    skippable = skippable,
                    notSkippable = not skippable,
                    selectable = selectable,
                    notSelectable = not selectable
                }

                if p.HasWaypointRef() then
                    pointInfo.pointName = p.WaypointRef()
                else
                    local d = distanceFormat(distances[index])
                    pointInfo.pointName = string.format("%0.1f%s", d.value, d.unit)
                end

                editRoute.points[tostring(index)] = pointInfo
            end
        else
            editRoute.name = "-"
        end

        -- Clear old data
        for i = pointsShown + 1, editRoutePointsPerPage, 1 do
            editRoute.points[tostring(i)] = {
                visible = false,
                gate = false,
                notGate = false,
                skippable = false,
                notSkippable = false,
                selectable = false,
                notSelectable = false
            }
        end

        dataToScreen.Set("editRoute", editRoute)

        local availableWaypoints = {
            currentPage = waypointPage,
            pageCount = rc.GetWaypointPages(waypointsPerPage),
            wayPoints = {}
        }

        local waypoints = rc.GetWaypointPage(waypointPage, waypointsPerPage)
        for index, p in ipairs(waypoints) do
            availableWaypoints.wayPoints[tostring(index)] = {
                visible = true,
                name = p.name,
                pos = p.point.Pos()
            }
        end

        for i = #waypoints + 1, waypointsPerPage, 1 do
            availableWaypoints.wayPoints[tostring(i)] = { visible = false }
        end

        dataToScreen.Set("availableWaypoints", availableWaypoints)
    end

    function s.updateFloorData()
        local points = rc.SelectableFloorPoints()

        local floorSelection = {
            routeName = rc.FloorRouteName(),
            points = {},
            currentPage = floorPage,
            pageCount = pagination.GetPageCount(points, floorPointsPerPage)
        }

        local selectable = pagination.Paginate(points, floorPage, floorPointsPerPage)

        floorSelection.currentPage = floorPage
        for i, p in ipairs(selectable) do
            floorSelection.points[tostring(i)] = p
        end

        -- Clear any removed points
        for i = #selectable + 1, floorPointsPerPage, 1 do
            floorSelection.points[tostring(i)] = { visible = false, name = "", index = "0" }
        end

        dataToScreen.Set("floorSelection", floorSelection)
    end

    ---@param routeName string
    ---@return boolean
    function s.ActivateFloorMode(routeName)
        local r = rc.LoadFloorRoute(routeName)
        if r then
            floorPage = 1
            s.updateFloorData()
            stream.Write({ activate_page = "status,floor" })
        end
        return r ~= nil
    end

    local function screenTask()
        local screen = library.getLinkByClass("ScreenUnit")

        if not screen then return end
        log.Info("Screen found")

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
                dataToScreen.Set("deviation/distance",
                    string.format("%0.2f", Vec3.New(data.long, data.lat, data.ver):Len()))
            end)

        pub.RegisterTable("FloorMonitor",
            ---@param _ string
            ---@param value TelemeterResult
            function(_, value)
                local floor = string.format("Hit: %s, distance: %0.2f, limit: %0.2f",
                    tostring(value.Hit), value.Distance,
                    settings.Number("autoShutdownFloorDistance"))
                dataToScreen.Set("floor", floor)
            end)

        stream = Stream.New(ScreenDevice.New(screen), s, 1)

        while screen do
            screen.activate()
            coroutine.yield()
            stream.Tick()

            if not stream.WaitingToSend() then
                if not routeTimer.IsRunning() or routeTimer.Elapsed() > 2 then
                    s.sendRoutes()
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
    Task.New("ScreenController", screenTask)
        .Then(function(...)
            log.Info("No screen connected")
        end).Catch(function(t)
        log.Error(t.Name(), t.Error())
    end)

    return setmetatable(s, ScreenController)
end

return ScreenController
