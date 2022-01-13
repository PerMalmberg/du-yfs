local calc = {
    Round = function(number, decimalPlaces)
        local mult = 10^(decimalPlaces or 0)
        return math.floor(number * mult + 0.5) / mult
    end
}

return calc
