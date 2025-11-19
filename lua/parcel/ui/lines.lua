local constants = require("parcel.constants")

local Text = require("parcel.ui.text")

--- A wrapper class around an array of formatted lines
---@class parcel.ui.Lines
---@field _buffer integer
---@field _row integer the start row for rendering lines
---@field _col integer the start col for rendering lines
---@field _sep string
---@field _line_count integer
---@field _rows (parcel.ui.InlineElement | parcel.ui.Grid)[]
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
---@return parcel.ui.Lines
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

---@param values string | parcel.ui.InlineElement | parcel.ui.Grid
---@return parcel.ui.Lines
function Lines:add(values)
    if type(values) == "string" then
        table.insert(self._rows, Text.new({ values }))
    else
        table.insert(self._rows, values)
    end

    return self
end

---@param condition boolean?
function Lines:newline(condition)
    if condition == nil or condition == true then
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
function Lines:size()
    return #self._rows
end

---@private
---@param line string
---@return string
function Lines:render_line(line)
    return (" "):rep(self._col) .. self._sep .. line
end

---@param pos { [1]: integer, [2]: integer }?
function Lines:render(pos)
    -- TODO: Could we instead create two extmarks to keep track of the position
    -- of the lines?
    local lines = {}
    local render_row = self._row
    local render_col = self._col

    if pos then
        render_row, render_col = pos[1], pos[2]
    end

    -- 1. Construct rendered string
    for _, row in ipairs(self._rows) do
        if row == "\n" then
            -- Empty newline
            table.insert(lines, self:render_line(""))
        else
            -- Row is an element that can render itself
            vim.list_extend(lines, row:render())
        end
    end

    -- 2. Set lines in buffer
    -- FIX: Adding 1 to the end row also removes the first line in fresh buffer but
    -- only for Lines for the entire file, false strict indexing might fix it
    vim.api.nvim_buf_set_lines(self._buffer, render_row, render_row, false, lines)

    self._line_count = #lines

    -- 3. Set highlights
    self:render_highlights(render_row, render_col)
end

---@private
---@param render_row integer
---@param render_col integer
function Lines:render_highlights(render_row, render_col)
    local lnum = render_row

    for _, row in ipairs(self._rows) do
        if row == "\n" then
            lnum = lnum + 1
        else
            -- Line is an element that can set highlights itself
            lnum = row:set_highlight(lnum, render_col) + 1
        end
    end
end

---@param pos { [1]: integer, [2]: integer }?
function Lines:clear(pos)
    if self._line_count > 0 then
        local render_row = self._row
        local render_col = self._col

        if pos then
            render_row, render_col = pos[1], pos[2]
        end

        vim.api.nvim_buf_set_lines(self._buffer, render_row, render_row + self._line_count, true, {})
        self._line_count = 0
    end
end

function Lines:clear_contents()
    self._rows = {}
end

return Lines
