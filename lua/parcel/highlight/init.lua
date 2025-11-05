local highlight = {}

local hl_cache = {}

---@param color string
---@return boolean
local function is_hex_color(color)
    return color:match("^#[a-fA-F0-9]+$") ~= nil
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

---@param options table
function highlight.create(options)
    -- TODO: Separate namespaces for different things
    local exists = highlight.get_hl(ns_id, { name = name })

    if table.maxn(exists) ~= 0 then
        return exists
    end

    local colors = { force = true, default = false }

    colors = vim.tbl_extend("force", colors, resolve_color_spec(ns_id, "fg", options))
    colors = vim.tbl_extend("force", colors, resolve_color_spec(ns_id, "bg", options))

    highlight.set_hl(ns_id, name, colors)
end

return highlight
