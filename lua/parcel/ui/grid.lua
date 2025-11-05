local config = require("parcel.config")
local Row = require("parcel.ui.row")

---@class parcel.Highlight
---@field id integer
---@field hl_group string
---@field lnum integer
---@field start_col integer
---@field end_col integer

---@class parcel.Grid
---@field _buffer integer
---@field _lnum integer
---@field _indent integer
---@field _sep string
---@field _rows parcel.Row[]
---@field _line_extmarks parcel.Highlight[]
---@field _dirty boolean
local Grid = {}

Grid.__index = Grid

function Grid.new(options)
    return setmetatable({
        _buffer = options.buffer or vim.api.nvim_get_current_buf(),
        _lnum = options.lnum or 0,
        _indent = options.indent or 0,
        _sep = options.sep or "",
        _rows = {},
        _column_widths = {},
        _line_extmarks = {},
        _extmarks = {},
        _dirty = false,
    }, Grid)
end

---@private
function Grid:ensure_render()
    assert(#self._column_widths > 0, "Must render grid before calling column_offset")
end

---@return integer
function Grid:__len()
    return #self._rows
end

---@param columns parcel.Column[]
---@param idx integer?
function Grid:add_row(columns, idx)
    if #columns == 0 then
        return
    end

    local row = Row:new()
    row:set_columns(columns)

    table.insert(self._rows, idx or #self._rows + 1, row)
end

---@param idx integer
---@return parcel.Row
function Grid:row(idx)
    return self._rows[idx]
end

---@param idx integer
---@return integer
function Grid:column_offset(idx)
    self:ensure_render()

    return self._column_widths[idx].len
end

---@private
---@param options {
---    lnum: integer,
---    start_col: integer,
---    end_col: integer,
---    column: any,
--- }
function Grid:set_highlight(options)
    -- Create an extmark if there is a highlight or if we are setting the first
    -- column (for jumping between parcels in the ui)
    if options.column.hl ~= nil or options.start_col == 0 then
        local highlight = {
            hl_group = options.column.hl,
            lnum = self._lnum + options.lnum - 1,
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
    return vim.api.nvim_buf_get_extmark_by_id(self._buffer, config.namespace, id, {})
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
    return self._rows[row]:column(col).value
end

---@param value any
---@param row integer
---@param col integer
function Grid:set_cell(value, row, col)
    self._rows[row]:column(col):set_value(value)
end

---@param id integer
---@param value any
---@param col integer
---@param group string?
function Grid:render_col(id, value, col, group)
    -- local grid_row = self._extmarks[id]
    -- local rendered_row = self:render_row(self._rows[grid_row])
    local extmark = self:get_extmark_by_id(id)
    local _row = extmark[1]
    local old_value = self:get_cell(_row, col)

    if old_value == nil then
        return
    end

    if vim.api.nvim_buf_is_valid(self._buffer) then
        local bytelen = vim.fn.strlen(old_value)
        vim.api.nvim_buf_set_text(self._buffer, _row, 0, _row, bytelen, { value })

        vim.api.nvim_buf_set_extmark(self._buffer, config.namespace, _row, 0, {
            hl_group = group,
            end_col = bytelen,
        })
    end

    self:set_cell(value, _row, col)
end

---@private
---@param row parcel.Row
function Grid:render_row(row)
    return (" "):rep(self._indent) .. self._sep .. row:render(self._column_widths)
end

function Grid:render(row, col)
    local lines = {}
    self._column_widths = {}

    -- TODO: Handle uneven columns

    -- Find the maximum width of all columns
    for _, _row in ipairs(self._rows) do
        assert(Row.is_row(_row), "Non-row value found in grid")
        local col_offset = 0

        for col_idx, column in _row:iter() do
            if not self._column_widths[col_idx] then
                self._column_widths[col_idx] = {
                    len = 0,
                    bytelen = 0,
                    col = 0,
                }
            end

            self._column_widths[col_idx].len = math.max(self._column_widths[col_idx].len, column:size())

            self._column_widths[col_idx].bytelen = math.max(self._column_widths[col_idx].bytelen, column:bytesize())

            self._column_widths[col_idx].col = col_offset
            col_offset = col_offset + column:bytesize()
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
        -- TODO: This won't work for _indent > 0
        local col = 0 -- self._indent + vim.fn.strlen(self._sep)

        for _, column in row:iter() do
            local start_col = col
            col = col + column:bytesize()

            self:set_highlight({ lnum = lnum, start_col = start_col, end_col = col, column = column })
        end
    end
end

return Grid
