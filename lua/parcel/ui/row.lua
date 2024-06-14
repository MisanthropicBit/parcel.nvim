---@class parcel.Row
local Row = {}

Row.__index = Row

local Column = require("parcel.ui.column")

function Row:new()
    return setmetatable({
        _columns = {},
    }, Row)
end

function Row.is_row(row)
    return getmetatable(row) == Row
end

---@param columns table[]
function Row:set_columns(columns)
    self._columns = vim.tbl_map(function(options)
        return Column:new(options[1], options)
    end, columns)
end

function Row:column(idx)
    return self._columns[idx]
end

function Row:iter()
    return ipairs(self._columns)
end

---@param max_widths integer[]
---@return string
function Row:render(max_widths)
    local result = {}

    for idx = 1, #max_widths do
        table.insert(result, self._columns[idx]:render(max_widths[idx]))
    end

    return table.concat(result)
end

return Row
