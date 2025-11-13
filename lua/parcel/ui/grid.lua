local config = require("parcel.config")
local Row = require("parcel.ui.row")
local tblx = require("parcel.tblx")

---@class parcel.Highlight
---@field id integer
---@field hl_group string
---@field lnum integer
---@field start_col integer
---@field end_col integer

-- TODO: Use local rows/cols instead of highlight id?

---@alias parcel.ui.LocalRowIdx integer
---@alias parcel.ui.CellId integer

---@class parcel.ui.Grid
---@field _buffer integer
---@field _row integer Row to render grid at
---@field _col integer Column to render grid at
---@field _sep string Separator between columns
---@field _rows parcel.ui.Row[]
---@field _max_cell_widths integer[]
---@field _line_extmarks parcel.Highlight[]
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
        _line_extmarks = {},
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
--             table.insert(self._line_extmarks, highlight)
--         end
--     end
-- end

---@return parcel.Highlight[]
function Grid:get_line_highlights()
    return self._line_extmarks
end

---@private
---@param id integer
---@return vim.api.keyset.get_extmark_item_by_id
function Grid:get_extmark_by_id(id)
    return vim.api.nvim_buf_get_extmark_by_id(self._buffer, config.namespace, id, { details = true })
end

---@private
---@param highlight parcel.Highlight
---@param extmark any
---@return parcel.Highlight
function Grid:adjust_highlight_lnum(highlight, extmark)
    local _highlight = vim.deepcopy(highlight)

    if extmark then
        _highlight.lnum = extmark[1] + 1
    end

    return _highlight
end

--- Get the extmark nearest a line number
---@param row integer
---@return parcel.Highlight
function Grid:get_nearest_row(row)
    local prev_extmark = nil

    -- TODO: Simplify loop
    for idx, highlight in ipairs(self._line_extmarks) do
        local extmark = self:get_extmark_by_id(highlight.id)

        if extmark[1] == row - 1 then
            -- We landed exactly on the extmark, so return it
            return self:adjust_highlight_lnum(highlight, extmark)
        elseif extmark[1] > row - 1 then
            -- Extmark is below row so return the previous one
            local prev_highlight = self._line_extmarks[idx - 1] or highlight
            local _prev = prev_extmark or extmark

            return self:adjust_highlight_lnum(prev_highlight, _prev)
        end

        prev_extmark = extmark
    end

    return self:adjust_highlight_lnum(self._line_extmarks[#self._line_extmarks], prev_extmark)
end

---@param row integer
---@return integer?
function Grid:get_prev(row)
    local prev_extmark = nil

    for idx = #self._line_extmarks, 1, -1 do
        local highlight = self._line_extmarks[idx]
        local extmark = self:get_extmark_by_id(highlight.id)

        if extmark[1] < row - 1 then
            return extmark[1] + 1
        end
    end

    return nil
end

---@param lnum integer
---@return integer?
function Grid:get_next(lnum)
    for idx, highlight in ipairs(self._line_extmarks) do
        local extmark = self:get_extmark_by_id(highlight.id)

        if extmark[1] > lnum - 1 then
            return extmark[1] + 1
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

---@param row integer
---@param col integer
---@return string[]
function Grid:render(row, col)
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
        table.insert(lines, indent_sep .. _row:render(row + idx - 1, col, render_options))
    end

    return lines
end

---@param row integer
---@param col integer
function Grid:set_highlight(row, col)
    self._line_extmarks = {}

    for row_idx, _row in ipairs(self._rows) do
        local offset = col

        for cell_idx, cell in _row:iter() do
            cell:set_highlight(self._buffer, row + row_idx - 1, offset)

            if cell_idx == 1 then
                -- TODO: Can we just use the info from getting the extmark?
                table.insert(self._line_extmarks, {
                    id = cell:highlight_id(),
                    lnum = self._row + row_idx, -- TODO: Rename to row
                    start_col = offset,
                    end_col = offset + cell:bytesize(),
                })
            end

            offset = offset + cell:bytesize()
        end

    end
end

return Grid
