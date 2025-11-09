local extmark = require("parcel.extmark")

---@class parcel.Label
---@field _buffer    integer
---@field _text      string
---@field _left_sep  string?
---@field _right_sep string?
---@field _lnum      integer
---@field _col       integer
---@field _end_col   integer
---@field _fg        string
---@field _bg        string
local Label = {}

Label.__index = Label

---@class parcel.LabelOptions
---@field buffer    integer?
---@field left_sep  string?
---@field right_sep string?
---@field text      string
---@field spacing   integer?
---@field lnum      integer
---@field col       integer
---@field fg        string
---@field bg        string

---@param options parcel.LabelOptions
function Label.new(options)
    local spacing = (" "):rep(options.spacing or 0)
    local text = ("%s%s%s"):format(spacing, options.text, spacing)

    return setmetatable({
        _buffer = options.buffer or 0,
        _text = text,
        _left_sep = options.left_sep or "",
        _right_sep = options.right_sep or "",
        _lnum = options.lnum,
        _col = options.col,
        _end_col = options.col + #text + 1,
        _fg = options.fg,
        _bg = options.bg,
        _extmark_ids = {},
    }, Label)
end

function Label:render()
    if #self._extmark_ids == 0 then
        self._extmark_ids = extmark.create(self._buffer, self._lnum, self._col, {
            { self._left_sep,  fg = self._bg },
            { self._text,      fg = self._fg, bg = self._bg },
            { self._right_sep, fg = self._bg },
        })
    end

    return self._left_sep .. self._text .. self._right_sep
end

function Label.bubble(options)
    return Label.new(vim.tbl_extend("force", options, {
        left_sep = "",
        right_sep = "",
    }))
end

function Label.slanted_right(options)
    return Label.new(vim.tbl_extend("force", options, {
        left_sep = " ",
        right_sep = " ",
    }))
end

Label.slanted_right({
    text = "winmove.nvim",
    lnum = 80,
    col = 3,
    fg = "#ffffff",
    bg = "#1398ab"
}):render()

--  winmove.nvim 

