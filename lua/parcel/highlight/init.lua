local highlight = {}

local constants = require("parcel.constants")

local hl_cache = {}

---@class parcel.HighlightOptions
---@field fg string?
---@field bg string?

---@param color string
---@return boolean
local function is_hex_color(color)
    return color and color:match("^#[a-fA-F0-9]+$") ~= nil
end

---@param options parcel.HighlightOptions
---@return string
local function create_cache_key(options)
    local cache_key = { "Parcel" }

    -- Strip '#' from hex colors as they are not allowed in highlight group names
    if options.fg then
        table.insert(cache_key, "fg" .. (is_hex_color(options.fg) and options.fg:sub(2) or options.fg))
    end

    if options.bg then
        table.insert(cache_key, "bg" .. (is_hex_color(options.bg) and options.bg:sub(2) or options.bg))
    end

    return table.concat(cache_key, "_")
end

function highlight.has_hl(name)
    -- NOTE: Ignores namespaces
    return vim.fn.hlexists(name) == 1
end

---@param ns_id integer
---@param options table
---@return vim.api.keyset.get_hl_info
function highlight.get_hl(ns_id, options)
    return vim.api.nvim_get_hl(ns_id, vim.tbl_extend("force", options, { link = false }))
end

---@param ns_id integer
---@param name string
---@param options table
function highlight.set_hl(ns_id, name, options)
    vim.api.nvim_set_hl(ns_id, name, options)
end

local function resolve_color_spec(ns_id, key, options)
    if options[key] then
        if is_hex_color(options[key][1]) then
            return { fg = options[key][1] }
        else
            local group = highlight.get_hl(ns_id, { name = options[key][1] })

            if group[options[key][2]] then
                return { [key] = group[options[key][2]] }
            -- else
            --     return { [key] = group[options[key == "fg" and "bg" or "fg"][2]] }
            end
        end
    end

    return { [key] = options[key][2] }
end

---@param options parcel.HighlightOptions
function highlight.create(options)
    local cache_key = create_cache_key(options)

    if hl_cache[cache_key] then
        return hl_cache[cache_key]
    end

    local colors = { force = true, default = false }

    -- TODO: Separate namespaces for different things
    colors = vim.tbl_extend("force", colors, options)
    colors = vim.tbl_extend("force", colors, options)

    highlight.set_hl(0, cache_key, colors)

    return cache_key
end

return highlight
