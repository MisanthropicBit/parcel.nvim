---@class parcel.ui.Row
---@field _cells parcel.ui.Cell[]
local Row = {}

Row.__index = Row

local Cell = require("parcel.ui.cell")

---@class parcel.ui.RowOptions
---@field cells parcel.ui.CellOptions[]

---@param options parcel.ui.RowOptions?
---@return parcel.ui.Row
function Row.new(options)
    local row = setmetatable({ _cells = {} }, Row)

    if options and options.cells then
        row:set_cells(options.cells)
    end

    return row
end

---@param cells parcel.ui.CellOptions[]
function Row:set_cells(cells)
    self._cells = vim.tbl_map(function(options)
        return Cell.new(options)
    end, cells)
end

---@param idx integer
---@return parcel.ui.Cell?
function Row:get(idx)
    if idx < 1 or idx > #self._cells then
        return nil
    end

    return self._cells[idx]
end

---@return integer
function Row:size()
    return #self._cells
end

function Row:iter()
    return ipairs(self._cells)
end

---@param render_options parcel.ui.RenderOptions
---@return string
function Row:render(render_options)
    local result = {}

    for idx, cell in ipairs(self._cells) do
        table.insert(result, cell:render(render_options.max_cell_widths[idx]))
    end

    return table.concat(result)
end

return Row
