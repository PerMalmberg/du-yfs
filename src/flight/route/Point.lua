local PointOptions = require("flight/route/PointOptions")

-- This class represents a position and behavior in a route.
-- Keep data as small as possible.

---@alias PointPOD {pos:string, waypointRef?:string, opt:table}

---@class Point Represents a point/waypoint in a route
---@field New fun(pos:string, waypointRef?:string, options?:PointOptions):Point
---@field Pos fun():string Returns the ::pos{} string
---@field HasWaypointRef fun(s):boolean Returns true if the point has a waypoint reference
---@field WaypointRef fun():string|nil Returns the waypoint reference, if any
---@field SetWaypointRef fun(ref:string) Sets the waypoint reference.
---@field Persist fun():PointPOD Returns an opaque table suitable to serialize and store.
---@field Options fun():PointOptions Returns the options for this point
---@field LoadFromPOD fun(source:PointPOD):Point Loads a Point from a POD
local Point = {}
Point.__index = Point

---Creates a new Point
---@param pos string A ::pos{} string
---@param waypointRef? string A named waypoint reference or nil
---@param options? PointOptions Point options, or nil
---@return Point
function Point.New(pos, waypointRef, options)
    local s = {}

    local position = pos -- ::pos{} string
    local wpRef = waypointRef
    local opt = options or PointOptions.New()

    ---@return string A ::pos{} string
    function s.Pos()
        return position
    end

    ---Indicates if the point has a waypoint reference
    ---@return boolean
    function s.HasWaypointRef()
        return wpRef ~= nil and #wpRef > 0
    end

    ---Returns the name of the waypoint reference
    ---@return string|nil
    function s.WaypointRef()
        return wpRef
    end

    ---Sets the named waypoint reference
    ---@param ref string
    function s.SetWaypointRef(ref)
        wpRef = ref
    end

    ---Returns a persistable table version of the point
    ---@return PointPOD
    function s.Persist()
        local pod ---@type PointPOD
        pod = {
            pos = position,
            waypointRef = wpRef,
            opt = opt:Data() or {}
        }

        return pod
    end

    ---Returns the options for the point
    ---@return PointOptions
    function s.Options()
        return opt
    end

    return setmetatable(s, Point)
end

---Loads data from a PointPOD
---@param source PointPOD
function Point.LoadFromPOD(source)
    return Point.New(source.pos, source.waypointRef, PointOptions.New(source.opt))
end

return Point
