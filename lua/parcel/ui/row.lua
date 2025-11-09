---@class parcel.Row
---@field _cells parcel.Cell[]
local Row = {}

Row.__index = Row

local Cell = require("parcel.ui.cell")

---@class parcel.RowOptions
---@field cells parcel.CellOptions[]

---@param options parcel.RowOptions?
---@return parcel.Row
function Row.new(options)
    local row = setmetatable({ _cells = {} }, Row)

    if options and options.cells then
        row:set_cells(options.cells)
    end

    return row
end

---@param value unknown
---@return boolean
function Row.is_row(value)
    return getmetatable(value) == Row
end

---@param cells parcel.CellOptions[]
function Row:set_cells(cells)
    self._cells = vim.tbl_map(function(options)
        return Cell.new(options)
    end, cells)
end

---@param idx integer
---@return parcel.Cell?
function Row:get(idx)
    if idx < 1 or idx > #self._cells then
        return nil
    end

    return self._cells[idx]
end

function Row:iter()
    return ipairs(self._cells)
end

---@param max_widths { len: integer }[]
---@return string
function Row:render(max_widths)
    local result = {}

    for idx, cell in ipairs(self._cells) do
        table.insert(result, cell:render(max_widths[idx].len))
    end

    return table.concat(result)
end

return Row
