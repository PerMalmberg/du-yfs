--- Various utility functions
-- @module utils

local utils = {}

-- reimplementation of math.frexp, due to its removal from Lua 5.3 :(
-- courtesy of airstruck
local log2 = math.log(2)

local frexp = math.frexp or function(x)
	if x == 0 then return 0, 0 end
	local e = math.floor(math.log(math.abs(x)) / log2 + 1)
	return x / 2 ^ e, e
end

--- Clamps a value within the specified range.
-- @param value Input value
-- @param min Minimum output value
-- @param max Maximum output value
-- @return number
function utils.clamp(value, min, max)
	return math.max(math.min(value, max), min)
end

--- Returns `value` if it is equal or greater than |`size`|, or 0.
-- @param value
-- @param size
-- @return number
function utils.deadzone(value, size)
	return math.abs(value) >= size and value or 0
end

--- Check if value is equal or greater than threshold.
-- @param value
-- @param threshold
-- @return boolean
function utils.threshold(value, threshold)
	-- I know, it barely saves any typing at all.
	return math.abs(value) >= threshold
end

--- Scales a value from one range to another.
-- @param value Input value
-- @param min_in Minimum input value
-- @param max_in Maximum input value
-- @param min_out Minimum output value
-- @param max_out Maximum output value
-- @return number
function utils.map(value, min_in, max_in, min_out, max_out)
	return ((value) - (min_in)) * ((max_out) - (min_out)) / ((max_in) - (min_in)) + (min_out)
end

--- Linear interpolation.
-- Performs linear interpolation between 0 and 1 when `low` < `progress` < `high`.
-- @param progress (0-1)
-- @param low value to return when `progress` is 0
-- @param high value to return when `progress` is 1
-- @return number
function utils.lerp(progress, low, high)
	return progress * (high - low) + low
end

--- Hermite interpolation.
-- Performs smooth Hermite interpolation between 0 and 1 when `low` < `progress` < `high`.
-- @param progress (0-1)
-- @param low value to return when `progress` is 0
-- @param high value to return when `progress` is 1
-- @return number
function utils.smoothstep(progress, low, high)
	local t = utils.clamp((progress - low) / (high - low), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
end

--- Round number at a given precision.
-- Truncates `value` at `precision` points after the decimal (whole number if
-- left unspecified).
-- @param value
-- @param precision
-- @return number
function utils.round(value, precision)
	if precision then return utils.round(value / precision) * precision end
	return value >= 0 and math.floor(value+0.5) or math.ceil(value-0.5)
end

--- Wrap `value` around if it exceeds `limit`.
-- @param value
-- @param limit
-- @return number
function utils.wrap(value, limit)
	if value < 0 then
		value = value + utils.round(((-value/limit)+1))*limit
	end
	return value % limit
end

--- Check if a value is a power-of-two.
-- Returns true if a number is a valid power-of-two, otherwise false.
-- @author undef
-- @param value
-- @return boolean
function utils.is_pot(value)
	-- found here: https://love2d.org/forums/viewtopic.php?p=182219#p182219
	-- check if a number is a power-of-two
  return (frexp(value)) == 0.5
end

-- Square value
function utils.pow2(value)
  return value * value
end

--- Return the sign of a decimal
-- @return -1 if negative ; 1 if positive ; 0 if null
function utils.sign(x)
   if x<0 then
     return -1
   elseif x>0 then
     return 1
   else
     return 0
   end
end

return utils
