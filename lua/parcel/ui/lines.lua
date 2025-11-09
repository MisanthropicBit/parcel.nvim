local config = require("parcel.config")

--- An optionally highlighted piece of text
---@class parcel.Text
---@field value string
---@field hl? string

--- A wrapper class around an array of formatted lines
---@class parcel.Lines
---@field _buffer integer
---@field _row integer the start row for drawing lines
---@field _indent integer
---@field _sep string
---@field _line_count integer
---@field _rows (parcel.Text[] | parcel.Grid | parcel.Label)[]
local Lines = {
    _row = 0,
    _sep = "",
    _indent = 0,
}

Lines.__index = Lines

---@class parcel.LinesOptions
---@field buffer? integer
---@field row? integer
---@field indent? integer
---@field sep? string

---@param options? parcel.LinesOptions
---@return parcel.Lines
function Lines.new(options)
    local _options = options or {}

    return setmetatable({
        _buffer = _options.buffer or 0,
        _row = _options.row or 0,
        _indent = _options.indent,
        _sep = _options.sep,
        _line_count = 0,
        _rows = { {} },
    }, Lines)
end

---@param value string | string[] | parcel.UiElement
---@param hl? string
---@param options? table
---@return parcel.Lines
function Lines:add(value, hl, options)
    -- Insert into the same line until the newline method is called
    if type(value) == "string" then
        if options and options.args then
            value = value:format(unpack(options.args))
        end

        -- TODO: Expand highlight to take fg and bg
        value = { value = value, hl = hl }
    end

    table.insert(self._rows[#self._rows], value)

    return self
end

---@param condition boolean?
function Lines:newline(condition)
    if condition == nil or condition then
        table.insert(self._rows, {})
    end

    return self
end

---@param count integer?
function Lines:newlines(count)
    for i = 1, count or 1 do
        table.insert(self._rows, {})
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
    return (" "):rep(self._indent) .. self._sep .. line
end

-- TODO: Pass buffer and lnum to constructor instead
---@param buffer integer
function Lines:render(buffer)
    local lines = {}

    -- 1. Construct rendered string
    for _, row in ipairs(self._rows) do
        if #row == 0 then
            -- Empty newline
            table.insert(lines, self:render_line(""))
        elseif row[1].value ~= nil then
            -- Line is a list of text elements
            local line = vim.tbl_map(function(text)
                return text.value
            end, row)

            table.insert(lines, self:render_line(table.concat(line)))
        else
            -- Line is an element that can render itself
            local ui_element = row[1]
            -- TODO: Proper cast
            vim.list_extend(lines, ui_element:render(self._indent, 0))
        end
    end

    -- 2. Set lines in buffer
    vim.api.nvim_buf_set_lines(buffer, self._row, self._row, true, lines)

    self._line_count = #lines
    local lnum = self._row

    -- 3. Set extended marks
    for _, row in ipairs(self._rows) do
        if #row == 0 then
            lnum = lnum + 1
        elseif row[1].value ~= nil then
            local col = self._indent + vim.fn.strlen(self._sep)

            for _, text in ipairs(row) do
                local start_col = col
                col = col + vim.fn.strlen(text.value)

                if text.hl ~= nil then
                    local extmark = { hl_group = text.hl, end_col = col }

                    -- TODO: Do we need to do this every time?
                    vim.api.nvim_buf_set_extmark(buffer, config.namespace, lnum, start_col, extmark)
                end
            end

            lnum = lnum + 1
        else
            -- Line is an element that can set marks itself
            ---@diagnostic disable-next-line: undefined-field
            row[1]:set_highlights()

            ---@diagnostic disable-next-line: undefined-field
            lnum = lnum + #row[1]
        end
    end
end

function Lines:clear()
    if self._line_count > 0 then
        vim.api.nvim_buf_set_lines(self._buffer, self._row, self._row + self._line_count, true, {})
        self._line_count = 0
    end
end

return Lines
