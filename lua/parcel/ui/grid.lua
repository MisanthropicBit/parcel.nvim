local config = require("parcel.config")
local Row = require("parcel.ui.row")
local tblx = require("parcel.tblx")

-- TODO: Use local rows/cols instead of highlight id?

---@alias parcel.ui.RowId integer An id identifying a row even if the row is moved
---@alias parcel.ui.CellId integer An id identifying a cell even if the cell is moved

---@class parcel.ui.RowPos
---@field row_id parcel.ui.RowId
---@field row integer

---@class parcel.ui.Grid
---@field _buffer integer
---@field _row integer Row to render grid at
---@field _col integer Column to render grid at
---@field _sep string Separator between columns
---@field _rows parcel.ui.Row[]
---@field _max_cell_widths integer[]
---@field _row_ids parcel.ui.RowId[]
local Grid = {}

Grid.__index = Grid

function Grid.new(options)
    return setmetatable({
        _buffer = options.buffer or vim.api.nvim_get_current_buf(),
        _row = options.row or 0,
        _col = options.col or 0,
        _sep = options.sep or "",
        _rows = {},
        _max_cell_widths = {},
        _row_ids = {},
    }, Grid)
end

---@param cells parcel.ui.CellOptions[]
---@param idx integer?
---@return parcel.ui.Grid
function Grid:add_row(cells, idx)
    assert(#cells > 0, "Must provide at least one cell for row")

    table.insert(self._rows, idx or #self._rows + 1, Row.new({ cells = cells }))

    return self
end

-- function Grid:delete_row(row_idx)
-- end

---@return integer
function Grid:row_count()
    return #self._rows
end

---@param idx integer
---@return parcel.ui.Row?
function Grid:row(idx)
    if idx < 1 or idx > #self._rows then
        return nil
    end

    return self._rows[idx]
end

---@private
---@param options {
---    row: integer,
---    start_col: integer,
---    end_col: integer,
---    cell: parcel.ui.Cell,
--- }
-- function Grid:set_highlight(options)
--     -- Create an extmark if there is a highlight or if we are setting the first
--     -- cell (for jumping between parcels in the ui)
--     if options.cell.hl ~= nil or options.start_col == 0 then
--         local highlight = {
--             hl_group = options.cell.hl,
--             lnum = self._row + options.row - 1,
--             start_col = options.start_col,
--             end_col = options.end_col,
--         }
--
--         highlight.id =
--             vim.api.nvim_buf_set_extmark(self._buffer, config.namespace, highlight.lnum - 1, highlight.start_col, {
--                 hl_group = highlight.hl_group,
--                 end_col = highlight.end_col,
--             })
--
--         -- If the highlight is at the start of a line, save it so we can use it
--         -- to find positions near the cursor
--         if options.start_col == 0 then
--             -- TODO: Add an empty extmark if no highlight
--             table.insert(self._row_ids, highlight)
--         end
--     end
-- end

---@return parcel.ui.RowId[]
function Grid:row_ids()
    return self._row_ids
end

---@private
---@param id integer
---@return vim.api.keyset.get_extmark_item_by_id
function Grid:get_extmark_by_id(id)
    return vim.api.nvim_buf_get_extmark_by_id(self._buffer, config.namespace, id, { details = true })
end

---@param lnum integer
---@return parcel.ui.RowPos?
function Grid:get_row_at_cursor(lnum)
    for idx, row_id in ipairs(self._row_ids) do
        local extmark = self:get_extmark_by_id(row_id)

        if extmark[1] == lnum - 1 then
            return { row_id = row_id, row = extmark[1] + 1 }
        end
    end
end

--- Get the row position on a line number or the nearest previous one
---@param lnum integer
---@return parcel.ui.RowPos
function Grid:get_row_or_previous(lnum)
    local prev_row_id = nil
    local prev_row = nil

    for idx, row_id in ipairs(self._row_ids) do
        local extmark = self:get_extmark_by_id(row_id)

        if extmark[1] == lnum - 1 then
            -- We landed exactly on the extmark, so return it
            return { row_id = row_id, row = extmark[1] + 1 }
        elseif extmark[1] > lnum - 1 then
            -- Extmark is below lnum so return the previous one or this one if
            -- no previous
            return { row_id = prev_row_id or row_id, row = (prev_row or extmark[1]) + 1 }
        end

        prev_row_id = row_id
        prev_row = extmark[1]
    end

    local last_row_id = self._row_ids[#self._row_ids]
    local extmark = self:get_extmark_by_id(last_row_id)

    return { row_id = last_row_id, row = extmark[1] + 1 }
end

---@param lnum integer
---@return { row_id: parcel.ui.RowId?, row: integer }?
function Grid:get_prev(lnum)
    local prev_row_id = nil

    for idx = #self._row_ids, 1, -1 do
        local row_id = self._row_ids[idx]
        local extmark = self:get_extmark_by_id(row_id)

        if extmark[1] < lnum - 1 then
            return { row_id = row_id, row = extmark[1] + 1 }
        end
    end

    return nil
end

---@param lnum integer
---@return { row_id: parcel.ui.RowId?, row: integer }?
function Grid:get_next(lnum)
    for idx, row_id in ipairs(self._row_ids) do
        local extmark = self:get_extmark_by_id(row_id)

        if extmark[1] > lnum - 1 then
            return { row_id = row_id, row = extmark[1] + 1 }
        end
    end

    return nil
end

---@param row integer
---@param col integer
---@return any
function Grid:get_cell(row, col)
    return self._rows[row]:get(col).value
end

---@param value any
---@param row integer
---@param col integer
function Grid:set_cell(value, row, col)
    -- TODO: Create a new method where row is a line number instead
    self._rows[self._row - row + 1]:get(col):set_value(value)
end

---@param id integer
---@param value any
---@param col integer
function Grid:render_cell(id, value, col)
    -- FIX:
    -- TODO: How do we specific (row, col) if things are based on extmark ids?
    -- * Map id to (row, col, ...end values) and vice versa?
    -- TODO: Create a new method for non-id version?
    if not vim.api.nvim_buf_is_valid(self._buffer) then
        return
    end

    local extmark = self:get_extmark_by_id(id)
    local _row, _col = extmark[1], extmark[2]
    local row = self._rows[1]
    local cell = row:get(1)

    if not cell then
        return
    end

    local prev_bytesize = cell:bytesize()
    local end_col = _col + prev_bytesize

    cell:set_value(value)
    local text = cell:render(self._max_cell_widths[1])

    vim.api.nvim_buf_set_text(self._buffer, _row, _col, _row, end_col, { text })

    vim.api.nvim_buf_set_extmark(self._buffer, config.namespace, _row, _col, {
        id = id,
        end_row = _row,
        end_col = end_col,
    })
end

---@return string[]
function Grid:render()
    -- TODO: Handle uneven cells
    local lines = {}
    self._max_cell_widths = tblx.fill_list(self._rows[1]:size(), 0)

    -- Find the maximum width of cells in each row for aligning columns
    for _, _row in ipairs(self._rows) do
        for col_idx, cell in _row:iter() do
            self._max_cell_widths[col_idx] = math.max(self._max_cell_widths[col_idx], cell:size())
        end
    end

    local indent_sep = (" "):rep(self._col) .. self._sep
    local render_options = { max_cell_widths = self._max_cell_widths }

    -- Render rows
    for idx, _row in ipairs(self._rows) do
        table.insert(lines, indent_sep .. _row:render(render_options))
    end

    return lines
end

---@param row integer
---@param col integer
---@return integer
function Grid:set_highlight(row, col)
    self._row_ids = {}

    for row_idx, _row in ipairs(self._rows) do
        local offset = col

        for cell_idx, cell in _row:iter() do
            local cell_id = cell:set_highlight(self._buffer, row + row_idx - 1, offset)

            -- TODO: Just create a extmark we manage ourselves
            if cell_idx == 1 then
                table.insert(self._row_ids, cell_id)
            end

            offset = offset + cell:bytesize()
        end
    end

    return row + #self._rows
end

return Grid
