local highlight = {}

local constants = require("parcel.constants")

local hl_cache = {}

---@alias parcel.HighlightOptions vim.api.keyset.highlight

---@param color string | integer
---@return boolean
local function is_hex_color(color)
    return type(color) == "string" and color:match("^#[a-fA-F0-9]+$") ~= nil
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

---@param options string | parcel.HighlightOptions
function highlight.create(options)
    if type(options) == "string" then
        return options
    end

    local cache_key = create_cache_key(options)

    if hl_cache[cache_key] then
        return cache_key
    end

    local colors = vim.tbl_extend("force", { force = true, default = false }, options)

    vim.api.nvim_set_hl(constants.hl_namespace, cache_key, colors)
    hl_cache[cache_key] = true

    return cache_key
end

return highlight
