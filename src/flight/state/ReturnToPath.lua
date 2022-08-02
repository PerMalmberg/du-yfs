local r = require("CommonRequire")
local brakes = r.brakes
local checks = r.checks
local vehicle = r.vehicle
local engine = r.engine
local Stopwatch = require("du-libs:system/StopWatch")

local Velocity = vehicle.velocity.Movement
local Position = vehicle.position.Current

local state = {}
state.__index = state
local name = "ReturnToPath"

local function new(fsm, returnPoint)
    checks.IsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm,
        returnPoint = returnPoint,
        returnPointAdjusted = false,
        sw = Stopwatch()
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
end

function state:Leave()
end

function state:Flush(next, previous, chaseData)
    local moveDir = Velocity():normalize()
    -- Start with trying to get back to the closest point on the line
    local toLine = chaseData.nearest - Position()
    local dirToLine = toLine:normalize()

    if not self.returnPointAdjusted and moveDir:dot(dirToLine) < 0.8 then
        -- Still moving away from the line, brake and give thrust
        brakes:Set(true)
        self.fsm:Thrust(dirToLine * engine:GetMaxPossibleAccelerationInWorldDirectionForPathFollow(dirToLine))
    elseif not self.returnPointAdjusted then
        -- Moving to line, fix the return point to the currently closest point
        self.returnPoint = chaseData.nearest
        self.returnPointAdjusted = true
    end

    if self.returnPointAdjusted then
        local timer = self.sw
        local toReturn = self.returnPoint - Position()

        self.fsm:Move(toReturn:normalize(), toReturn:len(), next.maxSpeed)

        if toReturn:len() <= next.margin then
            if not timer:IsRunning() then
                timer:Start()
            end

            if timer:Elapsed() > 0.3 then
                self.fsm:SetState(Travel(self.fsm))
            end
        else
            timer:Stop()
        end
    end
end

function state:OverrideAdjustPoint()
    return self.returnPoint
end

function state:Update()
end

function state:WaypointReached(isLastWaypoint, next, previous)
end

function state:Name()
    return name
end

return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                return new(...)
            end
        }
)