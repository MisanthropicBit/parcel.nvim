local float = {}

---@class parcel.ui.FloatConfig
---@field enter boolean
---@field listed boolean
---@field scratch boolean

---@type parcel.ui.FloatConfig
local default_float_options = {
    listed = false,
    scratch = false,
    enter = false,
}

---@param buffer integer
---@param win_config vim.api.keyset.win_config
---@return integer
local function open_float(buffer, win_config)
    return vim.api.nvim_open_win(buffer, false, win_config)
end

---@param buffer integer
---@param options parcel.ui.FloatConfig?
---@return integer
function float.open_centered(buffer, options)
    local _options = vim.tbl_extend("force", options, default_float_options)

    local width_factor = 0.90
    local height_factor = 0.90
    local width = math.floor(vim.o.columns * width_factor)
    local height = math.floor(vim.o.lines * height_factor)
    local buffer = vim.api.nvim_create_buf(_options.listed, _options.scratch)

    -- TODO: Account for commandline height (check winmove.nvim)
    -- TODO: Allow overriding some options in config
    local win_config = {
        relative = "editor",
        anchor = "NW",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - vim.o.lines * height_factor) / 2),
        col = math.floor((vim.o.columns - vim.o.columns * width_factor) / 2),
        focusable = true,
        title = "parcel.nvim",
        title_pos = "center",
    }

    return open_float(buffer, win_config)
end

function float.open_at_pos() end

function float.open_at_cursor() end

return float
