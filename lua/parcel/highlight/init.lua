local highlight = {}

local constants = require("parcel.constants")
local utils = require("parcel.utils")

---@type table<string, string>
local hl_cache = {}

---@alias parcel.HighlightOptions vim.api.keyset.highlight

---@alias parcel.ColorSpec table<"fg" | "bg", string>

---@param color unknown
---@return boolean
local function is_hex_color(color)
    return type(color) == "string" and color:match("^#[a-fA-F0-9]+$") ~= nil
end

---@param hl_group string
---@return string?
local function get_hl_property(hl_group, prop)
    local hl_info = vim.api.nvim_get_hl(0, { name = hl_group, link = false, create = false })

    return hl_info.fg and string.format("#%06x", hl_info.fg) or nil
end

---@param options string | parcel.HighlightOptions
---@return string
local function create_cache_key(options)
    if type(options) == "string" then
        return options
    end

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

---@param ns_id integer
---@param key "fg" | "bg"
---@param options table
---@return table
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

---@param color string | { fg: string, bg: string }
---@return string, string
function highlight.create_for_label(color)
    local cache_key = create_cache_key(color)

    if hl_cache[cache_key] then
        return cache_key .. "Fg", cache_key .. "Bg"
    end

    local fg, bg

    if type(color) == "string" then
        if is_hex_color(color) then
            fg = color
        else
            ---@cast color string
            fg, bg = get_hl_property(color, "fg"), get_hl_property(color, "bg")
        end
    else
        fg, bg = color.fg, color.bg
    end

    if fg and not bg then
        bg = utils.color.constrast(fg)
    elseif not fg and bg then
        fg = get_hl_property("Normal", "fg")
    elseif not fg and not bg then
        fg = get_hl_property("Normal", "bg") or "#ffffff"
        bg = get_hl_property("Normal", "fg") or "#000000"
    end

    vim.api.nvim_set_hl(constants.hl_namespace, cache_key .. "Fg", { fg = fg, bg = bg })
    vim.api.nvim_set_hl(constants.hl_namespace, cache_key .. "Bg", { fg = bg })

    return cache_key .. "Fg", cache_key .. "Bg"
end

function highlight.setup()
    -- TODO: Should this be the global namespace instead?
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelTitle", { link = "Title" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelHelpText", { link = "Comment" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelActive", { link = "diffAdded" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelInactive", { link = "WarningMsg" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelUpdating", { link = "WarningMsg" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelUpdatesAvailable", { link = "WarningMsg" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelFailed", { link = "ErrorMsg" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelLoaded", { link = "diffAdded" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelIcon", { link = "Special" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelName", { link = "String" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelLabel", { link = "Number" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelDev", { link = "Identifier" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelSource", { link = "Special" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelVersion", { link = "Type" })
    vim.api.nvim_set_hl(constants.hl_namespace, "ParcelSectionKey", { link = "Keyword" })
end

return highlight
