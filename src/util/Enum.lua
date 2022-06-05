function Enum(tbl)
    local length = #tbl
    for i = 1, length do
        local v = tbl[i]
        tbl[v] = i
    end

    return tbl
end

--[[Usage

From: https://unendli.ch/posts/2016-07-22-enumerations-in-lua.html

When passing a literal table (or string) to a function in Lua the parentheses can be omitted which lets us create a handy DSL

Colors = Enum {
   "BLUE",
   "GREEN",
   "RED",
   "VIOLET",
   "YELLOW",
}

-- finally, get our integer from the enum!
local color = Colors.RED

]]
