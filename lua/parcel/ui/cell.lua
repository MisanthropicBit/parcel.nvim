local config = require("parcel.config")
local highlight = require("parcel.highlight")

---@alias parcel.CellAlignment "left" | "center" | "right"

---@alias parcel.HighlightGroup string A vim/neovim highlight group name such as "Special"

---@alias parcel.HighlightSpec vim.api.keyset.highlight Same as value passed to vim.api.nvim_set_hl

---@alias parcel.Highlight_ parcel.HighlightGroup | parcel.HighlightSpec

local utils = require("parcel.utils")

---@class parcel.ui.Cell
---@field _value string
---@field _align parcel.CellAlignment?
---@field _lpad integer
---@field _rpad integer
---@field _size integer
---@field _byte_size integer
---@field _hl_group string
---@field _extmark_id integer?
local Cell = {
    _align = "left",
    _lpad = 0,
    _rpad = 0,
    _size = 0,
    _byte_size = 0,
    _extmark_id = nil,
}

Cell.__index = Cell

---@class parcel.ui.CellOptions
---@field [1] boolean | string
---@field align parcel.CellAlignment?
---@field lpad integer?
---@field rpad integer?
---@field icon string?
---@field hl parcel.Highlight_?

---@param options parcel.ui.CellOptions
---@return parcel.ui.Cell
function Cell.new(options)
    local value = options[1]
    local cell = setmetatable(utils.privatise_options(options), Cell)

    if options.hl then
        if type(options.hl) == "string" then
            cell._hl_group = options.hl
        else
            cell._hl_group = highlight.create(options.hl)
        end
    end

    if type(value) == "boolean" then
        assert(options.icon, "Missing 'icon' field for boolean cell")
        cell.value = value and options.icon or " "
        cell:set_value(value and options.icon or " ")
    else
        cell:set_value(value)
    end

    return cell
end

--- Return the cell's width in characters
---@return integer
function Cell:size()
    return self._lpad + self._rpad + vim.fn.strwidth(self._value)
end

--- Return the cell's width in bytes
---@return integer
function Cell:bytesize()
    return self._byte_size
end

---@param value string
function Cell:set_value(value)
    self._value = value
end

---@return integer
function Cell:highlight_id()
    return self._extmark_id
end

---@param max_width integer
---@return string
function Cell:render(max_width)
    local result = {}
    local padding = max_width - self:size()
    local align = self._align or "left"

    -- First apply padding according to the maximum cell width
    if align == "right" then
        vim.list_extend(result, { (" "):rep(padding), self._value })
    elseif align == "left" then
        vim.list_extend(result, { self._value, (" "):rep(padding) })
    elseif align == "center" then
        local half_width = padding / 2

        vim.list_extend(result, { (" "):rep(half_width), self._value, (" "):rep(half_width) })
    end

    -- Apply left and right padding
    table.insert(result, 1, (" "):rep(self._lpad))
    table.insert(result, (" "):rep(self._rpad))

    -- Complete render and set sizes
    local rendered = table.concat(result)
    self._size = vim.fn.strwidth(rendered)
    self._byte_size = vim.fn.strlen(rendered)

    return rendered
end

---@param buffer integer
---@param row integer
---@param col integer
function Cell:set_highlight(buffer, row, col)
    self._extmark_id = vim.api.nvim_buf_set_extmark(buffer, config.namespace, row, col, {
        id = self._extmark_id,
        hl_group = self._hl_group,
        end_row = row,
        end_col = col + self:bytesize(),
    })
end

return Cell
