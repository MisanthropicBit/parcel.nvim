local config = require("parcel.config")
local highlight = require("parcel.highlight")
local Text = require("parcel.ui.text")
local utils = require("parcel.utils")

---@alias parcel.ui.CellAlignment "left" | "center" | "right"

---@class parcel.ui.Cell
---@field _value parcel.ui.InlineElement
---@field _align parcel.ui.CellAlignment?
---@field _lpad integer
---@field _rpad integer
---@field _size integer
---@field _byte_size integer
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
---@field [1] (string?) | parcel.ui.InlineElement
---@field align parcel.ui.CellAlignment?
---@field lpad integer?
---@field rpad integer?

---@param options parcel.ui.CellOptions
---@return parcel.ui.Cell
function Cell.new(options)
    local value = options[1]
    local cell = setmetatable(utils.privatise_options(options), Cell)

    if value == nil or type(value) == "string" then
        cell:set_value(Text.new(value or ""))
    else
        cell:set_value(value)
    end

    return cell
end

--- Return the cell's width in characters
---@return integer
function Cell:size()
    return self._lpad + self._rpad + self._value:size()
end

--- Return the cell's width in bytes
---@return integer
function Cell:bytesize()
    return self._byte_size
end

---@param value parcel.ui.InlineElement
function Cell:set_value(value)
    self._value = value
end

---@param max_width integer
---@return string
function Cell:render(max_width)
    local result = {}
    local padding = max_width - self:size()
    local value = vim.iter(self._value:render()):join("")

    -- First apply padding according to the maximum cell width
    if self._align == "left" then
        vim.list_extend(result, { value, (" "):rep(padding) })
    elseif self._align == "right" then
        vim.list_extend(result, { (" "):rep(padding), value })
    elseif self._align == "center" then
        local half_width = padding / 2

        vim.list_extend(result, { (" "):rep(half_width), value, (" "):rep(half_width) })
    end

    -- Apply left and right padding
    table.insert(result, 1, (" "):rep(1))
    table.insert(result, (" "):rep(1))

    -- Complete render and set sizes
    local rendered = table.concat(result)

    self._size = vim.fn.strwidth(rendered)
    self._byte_size = vim.fn.strlen(rendered)

    return rendered
end

---@param buffer integer
---@param row integer
---@param col integer
---@return parcel.ui.CellId
function Cell:set_highlight(buffer, row, col)
    return self._value:set_highlight(row, col + 1)
end

return Cell
