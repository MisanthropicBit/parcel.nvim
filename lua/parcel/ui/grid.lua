local config = require("parcel.config")
local Row = require("parcel.ui.row")

---@class parcel.Highlight
---@field id integer
---@field hl_group string
---@field lnum integer
---@field start_col integer
---@field end_col integer

-- TODO: Use local rows/cols instead of highlight id?

---@alias parcel.LocalGridRow integer
---@alias parcel.LocalGridCol integer

---@class parcel.Grid
---@field _buffer integer
---@field _row integer Row to render grid at
---@field _col integer Column to render grid at
---@field _sep string Separator between columns
---@field _rows parcel.Row[]
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
        _cell_widths = {},
        _line_extmarks = {},
        _extmarks = {},
    }, Grid)
end

---@private
function Grid:ensure_render()
    assert(#self._column_max_widths > 0, "Must render grid before calling cell_offset")
end

---@param cells parcel.Cell[]
---@param idx integer?
function Grid:add_row(cells, idx)
    assert(#cells > 0, "Must provide at least one cell for row")

    table.insert(self._rows, idx or #self._rows + 1, Row.new({ cells = cells }))
end

---@param idx integer
---@return parcel.Row?
function Grid:row(idx)
    if idx < 1 or idx > #self._rows then
        return nil
    end

    return self._rows[idx]
end

---@param idx integer
---@return integer?
function Grid:cell_offset(idx)
    -- TODO: Rename

    self:ensure_render()

    if idx < 1 or idx > #self._column_max_widths then
        return nil
    end

    return self._column_max_widths[idx].len
end

---@private
---@param options {
---    lnum: integer,
---    start_col: integer,
---    end_col: integer,
---    cell: any,
--- }
function Grid:set_highlight(options)
    -- Create an extmark if there is a highlight or if we are setting the first
    -- cell (for jumping between parcels in the ui)
    if options.cell.hl ~= nil or options.start_col == 0 then
        local highlight = {
            hl_group = options.cell.hl,
            lnum = self._row + options.lnum - 1,
            start_col = options.start_col,
            end_col = options.end_col,
        }

        -- Highlights use byte-based indexing
        highlight.id =
            vim.api.nvim_buf_set_extmark(self._buffer, config.namespace, highlight.lnum - 1, highlight.start_col, {
                hl_group = highlight.hl_group,
                end_col = highlight.end_col,
            })

        -- If the highlight is at the start of a line, save it so we can use it
        -- to find positions near the cursor
        if options.start_col == 0 then
            -- TODO: Add an empty extmark if no highlight
            table.insert(self._line_extmarks, highlight)
            self._extmarks[highlight.id] = #self._line_extmarks
        end
    end
end

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
    if extmark then
        highlight.lnum = extmark[1] + 1
    end

    return highlight
end

--- Get the extmark nearest a line number
---@param lnum integer
---@return parcel.Highlight
function Grid:get_nearest(lnum)
    local prev_extmark = nil

    -- TODO: Simplify loop
    for idx, highlight in ipairs(self._line_extmarks) do
        local extmark = self:get_extmark_by_id(highlight.id)

        if extmark[1] == lnum - 1 then
            return self:adjust_highlight_lnum(highlight, extmark)
        elseif extmark[1] > lnum - 1 then
            local prev_highlight = self._line_extmarks[idx - 1] or highlight
            local _prev = prev_extmark or extmark

            return self:adjust_highlight_lnum(prev_highlight, _prev)
        end

        prev_extmark = extmark
    end

    -- FIX: This modifies the lnum every time it is called
    return self:adjust_highlight_lnum(self._line_extmarks[#self._line_extmarks], prev_extmark)
end

---@param lnum integer
---@return integer?
function Grid:get_prev(lnum)
    local prev_extmark = nil

    for idx = #self._line_extmarks, 1, -1 do
        local highlight = self._line_extmarks[idx]
        local extmark = self:get_extmark_by_id(highlight.id)

        if extmark[1] < lnum - 1 then
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
---@param group string?
function Grid:render_col(id, value, col, group)
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

    local old_bytelen = cell:bytesize()
    cell:set_value(value)
    local text = cell:render(self._column_max_widths[1].len)

    -- vim.print(vim.inspect({ _row, _col, end_col, vim.fn.strlen(value) }))
    -- local old_value = self:get_cell(self._row - _row + 1, col)
    --
    -- -- TODO: Allow for missing old value
    -- if old_value == nil then
    --     return
    -- end

    -- 
    -- 
    -- vim-bracketed-paste
    -- 77e5220
    -- 󰐃
    --
    -- { "tick", 0.00126021 }
    -- { "frames", { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" } }
    -- { "idx", 1 }
    -- ⠋
    -- { 4, 0, 4, 5 }
    -- { "tick", 0.50585952 }
    -- { "frames", { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" } }
    -- { "idx", 6 }
    -- ⠴
    -- { 4, 0, 4, 7 }
    -- { "tick", 1.0060583 }
    -- { "frames", { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" } }
    -- { "idx", 1 }
    -- ⠋
    -- { 4, 0, 4, 9 }
    vim.print(vim.inspect({ _row, _col, _row, old_bytelen }))
    vim.api.nvim_buf_set_text(self._buffer, _row, _col, _row, _col + old_bytelen, { text })

    vim.api.nvim_buf_set_extmark(self._buffer, config.namespace, _row, _col, {
        -- hl_group = group,
        id = id,
        end_row = _row,
        end_col = _col + old_bytelen
    })

    -- self._column_max_widths[1].len = math.max(self._column_max_widths[1].len, cell:size())

    -- self:set_cell(value, _row, col)
end

---@private
---@param row parcel.Row
function Grid:render_row(row)
    return (" "):rep(self._col) .. self._sep .. row:render(self._column_max_widths)
end


---@param row integer
---@param col integer
function Grid:render(row, col)
    -- TODO: Handle uneven cells
    local lines = {}
    self._column_max_widths = {}

    -- Find the maximum width of all columns
    for _, _row in ipairs(self._rows) do
        assert(Row.is_row(_row), "Non-row value found in grid")

        for col_idx, cell in _row:iter() do
            if not self._column_max_widths[col_idx] then
                self._column_max_widths[col_idx] = { len = 0 }
            end

            self._column_max_widths[col_idx].len = math.max(self._column_max_widths[col_idx].len, cell:size())
        end
    end

    -- Render rows
    for _, _row in ipairs(self._rows) do
        table.insert(lines, self:render_row(_row))
    end

    return lines
end

function Grid:set_highlights()
    self._line_extmarks = {}
    self._extmarks = {}

    for lnum, row in ipairs(self._rows) do
        assert(Row.is_row(row), "Non-row value found in grid")
        -- TODO: This won't work for _col > 0
        local col = 0 -- self._col + vim.fn.strlen(self._sep)

        for _, cell in row:iter() do
            local start_col = col
            col = col + cell:bytesize()

            self:set_highlight({ lnum = lnum, start_col = start_col, end_col = col, cell = cell })
        end
    end
end

return Grid
