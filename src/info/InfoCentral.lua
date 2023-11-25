local s                              = require("Singletons")
local pub, calc, sharedPanel, format = s.pub, s.calc, require("panel/SharedPanel").Instance(), string.format

---@class InfoCentral
---@field Instance fun():InfoCentral
---@field SetBrake fun(data:BrakeData)

local InfoCentral                    = {}
InfoCentral.__index                  = InfoCentral
local instance

function InfoCentral.Instance()
    if instance then return instance end

    local s = {}

    local brakeInfo = {
        visible       = false,
        panel         = nil,
        wDeceleration = nil,
        wCurrentDec   = nil,
        wPid          = nil,
    }

    local flightInfo = {
        visible = false,
        targetSpeed = 0,
        wStateName = nil,
        wPointDistance = nil,
        wAcceleration = nil,
        wCtrlAcceleration = nil,
        wTargetSpeed = nil,
        wFinalSpeed = nil,
        wSpeedDiff = nil,
        wBrakeMaxSpeed = nil,
        wPid = nil,
        wDistToAtmo = nil,
        wSpeed = nil,
        wAdjTowards = nil,
        wAdjDist = nil,
        wAdjAcc = nil,
        wAdjBrakeDistance = nil,
        wAdjSpeed = nil
    }

    local adjustInfo = {
        visible = false,
        panel = nil,
        wAdjTowards = nil,
        wAdjDist = nil,
        wAdjAcc = nil,
        wAdjBrakeDistance = nil,
        wAdjSpeed = nil
    }

    local axisInfo = {
        visible = false,
        pitchPanels = nil,
        rollPanels = nil,
        yawPanels = nil,
    }

    local waypointInfo = {
        visible = false,
        wDistance = nil,
        wMargin = nil,
        wFinalSpeed = nil,
        wMaxSpeed = nil,
    }

    pub.RegisterBool("ShowInfoWidgets", function(_, value)
        brakeInfo.visible = value
        flightInfo.visible = value
        adjustInfo.visible = value
        axisInfo.visible = value
        waypointInfo.visible = value

        if value then
            unit.showWidget()
        else
            unit.hideWidget()
        end

        system.showHelper(value)
    end)

    unit.hideWidget()
    system.showHelper(false)

    ---@param value BrakeData
    pub.RegisterTable("BrakeData", function(topic, value)
        if not brakeInfo.panel and brakeInfo.visible then
            local p = sharedPanel.Get("Brake")
            brakeInfo.panel = p
            brakeInfo.wMaxDeceleration = p.CreateValue("Max deceleration", "m/s2")
            brakeInfo.wCurrentDec = p.CreateValue("Brake dec.", "m/s2")
            brakeInfo.wPid = p.CreateValue("Pid")
            brakeInfo.wAutoBrakeAngle = p.CreateValue("Auto brake angle")
        elseif brakeInfo.panel and not brakeInfo.visible then
            sharedPanel.Close("Brake")
            brakeInfo.panel = nil
        end

        if brakeInfo.panel then
            brakeInfo.wMaxDeceleration.Set(calc.Round(value.maxDeceleration, 2))
            brakeInfo.wCurrentDec.Set(calc.Round(value.currentDeceleration, 2))
            brakeInfo.wPid.Set(calc.Round(value.pid, 4))
            brakeInfo.wAutoBrakeAngle.Set(format("%.1f/%.1f", value.autoBrakeAngle, value.setAutoBrakeAngle))
        end
    end)

    ---@param topic string
    ---@param value FlightData
    pub.RegisterTable("FlightData", function(topic, value)
        if not flightInfo.panel and flightInfo.visible then
            local p = sharedPanel.Get("Movement")
            flightInfo.panel = p
            flightInfo.wStateName = p.CreateValue("State", "")
            flightInfo.wPointDistance = p.CreateValue("Point dist.", "m")
            flightInfo.wAcceleration = p.CreateValue("Acceleration", "m/s2")
            flightInfo.wCtrlAcceleration = p.CreateValue("Ctrl. acc.", "m/s2")
            flightInfo.wTargetSpeed = p.CreateValue("Target speed")
            flightInfo.wFinalSpeed = p.CreateValue("Final speed")
            flightInfo.wSpeedDiff = p.CreateValue("Speed diff", "km/h")
            flightInfo.wBrakeMaxSpeed = p.CreateValue("Brake Max Speed", "km/h")
            flightInfo.wPid = p.CreateValue("Pid")
            flightInfo.wDistToAtmo = p.CreateValue("Atmo dist.", "m")
            flightInfo.wSpeed = p.CreateValue("Abs. speed", "km/h")
        elseif brakeInfo.panel and not brakeInfo.visible then
            sharedPanel.Close("Movement")
            flightInfo.panel = nil
        end

        if flightInfo.panel then
            flightInfo.wStateName.Set(value.fsmState)
            flightInfo.wPointDistance.Set(calc.Round(value.waypointDist, 2))
            flightInfo.wAcceleration.Set(format("%.1f", value.acceleration))
            flightInfo.wCtrlAcceleration.Set(format("%.1f", value.controlAcc))
            flightInfo.wTargetSpeed.Set(format("%.1f (%s)", calc.Mps2Kph(value.targetSpeed), value.targetSpeedReason))
            flightInfo.wFinalSpeed.Set(format("%.1f km/h in %.1f m", calc.Mps2Kph(value.finalSpeed),
                value.finalSpeedDistance))
            flightInfo.wSpeedDiff.Set(calc.Round(calc.Mps2Kph(value.speedDiff), 1))
            flightInfo.wBrakeMaxSpeed.Set(calc.Round(calc.Mps2Kph(value.brakeMaxSpeed)))
            flightInfo.wPid.Set(calc.Round(value.pid, 4))
            flightInfo.wDistToAtmo.Set(calc.Round(value.distanceToAtmo, 1))
            flightInfo.wSpeed.Set(calc.Round(calc.Mps2Kph(value.absSpeed), 1))
        end
    end)

    ---@param topic string
    ---@param value AdjustmentData
    pub.RegisterTable("AdjustmentData", function(topic, value)
        if not adjustInfo.panel and adjustInfo.visible then
            local p = sharedPanel.Get("Adjustment")
            adjustInfo.panel = p
            adjustInfo.wLong = p.CreateValue("Long", "m")
            adjustInfo.wLat = p.CreateValue("Lat", "m")
            adjustInfo.wVert = p.CreateValue("Vert", "m")
        elseif adjustInfo.panel and not adjustInfo.visible then
            sharedPanel.Close("Adjustment")
            adjustInfo.panel = nil
        end

        if adjustInfo.panel then
            adjustInfo.wLong.Set(calc.Round(value.long, 2))
            adjustInfo.wLat.Set(calc.Round(value.lat, 2))
            adjustInfo.wVert.Set(calc.Round(value.ver, 2))
        end
    end)

    ---@param p Panel
    ---@param axisName string
    local function createAxisValues(p, axis, axisName)
        axis.wTitle = p.CreateValue("Axis")
        axis.wTitle.Set(axisName)
        axis.wSpeed = p.CreateValue("Speed", "°/s")
        axis.wAcceleration = p.CreateValue("Acc.", "°/s2")
        axis.wOffset = p.CreateValue("Offset", "°")
    end

    local function setupAxisPanels()
        if not axisInfo.pitchPanels and axisInfo.visible then
            local p = sharedPanel.Get("Rotation")
            axisInfo.panel = p
            axisInfo.pitchPanels = {}
            createAxisValues(p, axisInfo.pitchPanels, "--- Pitch ---")
            axisInfo.rollPanels = {}
            createAxisValues(p, axisInfo.rollPanels, "--- Roll ---")
            axisInfo.yawPanels = {}
            createAxisValues(p, axisInfo.yawPanels, "--- Yaw ---")
        elseif axisInfo.pitchPanels and not axisInfo.visible then
            sharedPanel.Close("Rotation")
            adjustInfo.pitchPanels = nil
            adjustInfo.rollPanels = nil
            adjustInfo.yawPanels = nil
        end
    end

    ---@param p table
    ---@param value AxisControlData
    local function setAxisValues(p, value)
        p.wSpeed.Set(calc.Round(value.speed, 2))
        p.wAcceleration.Set(calc.Round(value.acceleration, 2))
        p.wOffset.Set(calc.Round(value.offset, 2))
    end

    ---@param topic string
    ---@param value AxisControlData
    pub.RegisterTable("PitchData", function(topic, value)
        axisInfo.pitch = value

        setupAxisPanels()

        if axisInfo.panel then
            local p = axisInfo.pitchPanels
            if p ~= nil then
                setAxisValues(p, value)
            end
        end
    end)

    ---@param topic string
    ---@param value AxisControlData
    pub.RegisterTable("RollData", function(topic, value)
        axisInfo.roll = value

        setupAxisPanels()

        if axisInfo.panel then
            local p = axisInfo.rollPanels
            if p ~= nil then
                setAxisValues(p, value)
            end
        end
    end)

    ---@param topic string
    ---@param value AxisControlData
    pub.RegisterTable("YawData", function(topic, value)
        axisInfo.pitch = value

        setupAxisPanels()

        if axisInfo.panel then
            local p = axisInfo.yawPanels
            if p ~= nil then
                setAxisValues(p, value)
            end
        end
    end)

    pub.RegisterTable("WaypointData",
        ---@param topic string
        ---@param waypoint Waypoint
        function(topic, waypoint)
            if not waypointInfo.panel and waypointInfo.visible then
                local p = sharedPanel.Get("Waypoint")
                waypointInfo.panel = p
                waypointInfo.wDistance = p.CreateValue("Distance", "m")
                waypointInfo.wMargin = p.CreateValue("Margin", "m")
                waypointInfo.wFinalSpeed = p.CreateValue("Final speed", "km/h")
                waypointInfo.wMaxSpeed = p.CreateValue("Max speed", "km/h")
            elseif waypointInfo.panel and not waypointInfo.visible then
                sharedPanel.Close("Waypoint")
                waypointInfo.panel = nil
            end

            if waypointInfo.panel then
                waypointInfo.wDistance.Set(calc.Round(waypoint.DistanceTo(), 3))
                waypointInfo.wMargin.Set(calc.Round(waypoint.Margin(), 3))
                waypointInfo.wFinalSpeed.Set(calc.Round(calc.Kph2Mps(waypoint.FinalSpeed()), 1))
                waypointInfo.wMaxSpeed.Set(calc.Round(calc.Kph2Mps(waypoint.MaxSpeed()), 1))
            end
        end)

    instance = setmetatable(s, InfoCentral)
    return instance
end

return InfoCentral
