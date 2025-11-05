local Easing = {}

-- See https://easings.net for easing functions

---@alias parcel.Easing fun(value: number): number

---@type parcel.Easing
local function bounce_out(value)
	local n1 = 7.5625
	local d1 = 2.75

	if value < 1 / d1 then
		return n1 * value * value
	elseif value < 2 / d1 then
        value = value - 1.5
		return n1 * (value / d1) * value + 0.75
	elseif value < 2.5 / d1 then
        value = value - 2.25
		return n1 * (value / d1) * value + 0.9375
	else
        value = value - 2.625
		return n1 * (value / d1) * value + 0.984375
    end
end

Easing.linear = function(value)
    return value
end

Easing.bounce = function(value)
    return 1 - bounce_out(1 - value)
end

return Easing
