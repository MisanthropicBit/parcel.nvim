local compat = require("parcel.compat")
local config = require("parcel.config")

--- An optionally highlighted piece of text
---@class parcel.Text
---@field value string
---@field hl? string

--- A wrapper class around an array of formatted lines
---@class parcel.Lines
---@field _offset integer
---@field _indent integer
---@field _sep string
---@field _line_count integer
---@field _rows (parcel.Text[] | parcel.Grid)[]
local Lines = {
    _offset = 0,
    _sep = "",
    _indent = 0,
}

---@class parcel.LinesOptions
---@field offset? integer
---@field indent? integer
---@field sep? string

---@param options? parcel.LinesOptions
---@return parcel.Lines
function Lines:new(options)
    local _options = options or {}

    local lines = {
        _offset = _options.offset,
        _indent = _options.indent,
        _sep = _options.sep,
        _line_count = 0,
        _rows = { {} },
    }
    self.__index = self

    return setmetatable(lines, self)
end

---@param value string | string[] | parcel.Grid
---@param hl? string
---@param options? table
---@return parcel.Lines
function Lines:add(value, hl, options)
    -- Insert into the same line until the newline method is called
    if type(value) == "string" then
        if options and options.args then
            value = value:format(unpack(options.args))
        end

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

function Lines:row()
    return #self._rows
end

---@param line string
---@return string
function Lines:_render_line(line)
    return (" "):rep(self._indent) .. self._sep .. line
end

---@param buffer integer
---@param lnum? integer
function Lines:render(buffer, lnum)
    local lines = {}

    -- Construct rendered string
    for _, row in ipairs(self._rows) do
        if #row == 0 then
            -- Empty newline
            table.insert(lines, self:_render_line(""))
        elseif row[1].value ~= nil then
            -- Line is a list of text elements
            local line = vim.tbl_map(function(text)
                return text.value
            end, row)

            table.insert(lines, self:_render_line(table.concat(line)))
        else
            -- Line is an element that can render itself
            ---@diagnostic disable-next-line: undefined-field
            vim.list_extend(lines, row[1]:render(self._indent, 0))
        end
    end

    if lnum then
        vim.api.nvim_buf_set_lines(buffer, lnum - 1, lnum - 1, true, lines)
    else
        vim.api.nvim_buf_set_lines(buffer, 0, -1, true, lines)
    end

    self._line_count = #lines

    if not compat.extmarks then
        -- TODO: Notify user
    end

    local _lnum = lnum or 1

    -- Set any highlights via extended marks
    for _, row in ipairs(self._rows) do
        if #row == 0 then
            _lnum = _lnum + 1
        elseif row[1].value ~= nil then
            local col = self._indent + vim.fn.strlen(self._sep)

            for _, text in ipairs(row) do
                local start_col = col
                col = col + vim.fn.strlen(text.value)

                if text.hl ~= nil then
                    local extmark = { hl_group = text.hl, end_col = col }

                    vim.print(config.namespace, buffer, _lnum, start_col, extmark)
                    vim.api.nvim_buf_set_extmark(
                        buffer,
                        config.namespace,
                        _lnum - 1,
                        start_col,
                        extmark
                    )
                end
            end

            _lnum = _lnum + 1
        else
            -- Line is an element that can set marks itself
            ---@diagnostic disable-next-line: undefined-field
            row[1]:set_highlights()

            ---@diagnostic disable-next-line: undefined-field
            _lnum = _lnum + #row[1]
        end
    end
end

function Lines:clear(buffer, lnum)
    if self._line_count > 0 then
        vim.api.nvim_buf_set_lines(
            buffer,
            lnum - 1,
            lnum + self._line_count - 1,
            true,
            {}
        )
        self._line_count = 0
    end
end

return Lines
