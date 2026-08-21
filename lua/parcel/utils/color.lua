local color_utils = {}

---@param hexcolor string
function color_utils.hex_to_rgb(hexcolor)
    local r = tonumber(hexcolor:sub(1, 2), 16)
    local g = tonumber(hexcolor:sub(3, 4), 16)
    local b = tonumber(hexcolor:sub(5, 6), 16)

    return r, g, b
end

---@param color string
---@return string?
function color_utils.constrast(color, factor)
    local r, g, b = color_utils.hex_to_rgb(color)
    local brightness = r * 299 + g * 587 + b * 114 / 1000

    if brightness >= 128 then
        -- Set luminance to dark version with factor
    else
        -- Set luminance to light version with factor
    end
end

return color_utils
