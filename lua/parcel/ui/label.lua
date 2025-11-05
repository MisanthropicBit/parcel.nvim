local constants = require("parcel.constants")
local highlight = require("parcel.highlight")

---@class parcel.Label
---@field _buffer     integer
---@field _text       string
---@field _start_lnum integer
---@field _end_lnum   integer
---@field _start_col  integer
---@field _end_col    integer
---@field _fg_color   string
---@field _bg_color   string
local Label = {}

Label.__index = Label

---@class parcel.LabelOptions
---@field buffer     integer?
---@field left_sep   string?
---@field right_sep  string?
---@field text       string
---@field spacing    integer?
---@field start_lnum integer
---@field end_lnum   integer
---@field start_col  integer
---@field end_col    integer
---@field fg_color   string
---@field bg_color   string

---@param options parcel.LabelOptions
function Label.new(options)
    local left_sep = options.left_sep or ""
    local right_sep = options.right_sep or ""
    local spacing = (" "):rep(options.spacing or 0)
    local text = ("%s%s%s%s%s"):format(left_sep, spacing, options.text, spacing, right_sep)

    local sep_hl_group = highlight.create({
        type = "LabelSep",
        fg = options.bg_color,
    })

    local hl_group = highlight.create({
        type = "Label",
        fg = options.fg_color,
        bg = options.bg_color,
    })

    return setmetatable({
        _buffer = options.buffer or 0,
        _text = text,
        _start_lnum = options.start_lnum,
        _end_lnum = options.end_lnum,
        _start_col = options.start_col,
        _end_col = options.end_col,
        _hl_group = hl_group,
        _extmark_id = nil,
    }, Label)
end

function Label:render()
    if not self._extmark_id then
        self._extmark_id =
            vim.api.nvim_buf_set_extmark(self._buffer, constants.namespace, self._start_lnum - 1, self._start_col, {
                end_row = self._end_lnum,
                end_col = self._end_col,
            })
    end

    return self._text
end
