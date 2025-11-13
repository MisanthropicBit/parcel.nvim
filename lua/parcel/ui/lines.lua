local config = require("parcel.config")

--- An optionally highlighted piece of text
---@class parcel.Text
---@field [1] string
---@field hl? parcel.Highlight_

--- A wrapper class around an array of formatted lines
---@class parcel.Lines
---@field _buffer integer
---@field _row integer the start row for drawing lines
---@field _col integer
---@field _sep string
---@field _line_count integer
---@field _rows (parcel.Text[] | parcel.ui.Grid | parcel.Label)[]
local Lines = {
    _row = 0,
    _sep = "",
    _col = 0,
}

Lines.__index = Lines

---@class parcel.LinesOptions
---@field buffer? integer
---@field row? integer
---@field col? integer
---@field sep? string

---@param options? parcel.LinesOptions
---@return parcel.Lines
function Lines.new(options)
    local _options = options or {}

    return setmetatable({
        _buffer = _options.buffer or 0,
        _row = _options.row or 0,
        _col = _options.col,
        _sep = _options.sep,
        _line_count = 0,
        _rows = {},
    }, Lines)
end

---@param value string | parcel.Text | parcel.Text[] | parcel.UiElement
---@return parcel.Lines
function Lines:add(value)
    if type(value) == "string" then
        table.insert(self._rows, { value })
    elseif type(value[1]) == "string" then
        table.insert(self._rows, { value })
    else
        table.insert(self._rows, value)
    end

    return self
end

---@param condition boolean?
function Lines:newline(condition)
    if condition == nil or condition then
        table.insert(self._rows, "\n")
    end

    return self
end

---@param count integer?
function Lines:newlines(count)
    for i = 1, count or 1 do
        table.insert(self._rows, "\n")
    end

    return self
end

---@return integer
function Lines:row_count()
    return #self._rows
end

---@private
---@param line string
---@return string
function Lines:render_line(line)
    return (" "):rep(self._col) .. self._sep .. line
end

function Lines:render()
    local lines = {}

    -- 1. Construct rendered string
    for _, row in ipairs(self._rows) do
        if row == "\n" then
            -- Empty newline
            table.insert(lines, self:render_line(""))
        elseif getmetatable(row) == nil then
            local contents = vim.tbl_map(function(value)
                return value[1]
            end, row)

            -- Line is a list of text elements
            table.insert(lines, self:render_line(table.concat(contents)))
        else
            -- Line is an element that can render itself
            vim.list_extend(lines, row:render(self._row, self._col))
        end
    end

    -- 2. Set lines in buffer
    -- FIX: Adding 1 to the end row also removes the first line in fresh buffer but
    -- only for Lines for the entire file, false strict indexing might fix it
    vim.api.nvim_buf_set_lines(self._buffer, self._row, self._row + 1, false, lines)

    self._line_count = #lines
    local lnum = self._row

    -- 3. Set extended marks
    for _, row in ipairs(self._rows) do
        if row == "\n" then
            lnum = lnum + 1
        elseif getmetatable(row) == nil then
            local col = self._col + vim.fn.strlen(self._sep)

            for _, value in ipairs(row) do
                local start_col = col
                col = col + vim.fn.strlen(value[1])

                if value.hl ~= nil then
                    local extmark = { hl_group = value.hl, end_row = lnum, end_col = col }

                    -- TODO: Do we need to do this every time?
                    vim.api.nvim_buf_set_extmark(self._buffer, config.namespace, lnum, start_col, extmark)
                end
            end

            lnum = lnum + 1
        else
            -- Line is an element that can set marks itself
            ---@diagnostic disable-next-line: undefined-field
            row:set_highlight(lnum, self._col)

            ---@diagnostic disable-next-line: undefined-field
            lnum = lnum + row:row_count()
        end
    end
end

function Lines:clear()
    if self._line_count > 0 then
        vim.api.nvim_buf_set_lines(self._buffer, self._row, self._row + self._line_count, true, {})
        self._line_count = 0
    end
end

function Lines:clear_contents()
    self._rows = {}
end

return Lines
