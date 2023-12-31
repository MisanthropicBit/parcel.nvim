---@class parcel.Row
local Row = {}

local Column = require("parcel.ui.column")

function Row:new()
    self.__index = self

    local row = setmetatable({
        _columns = {},
    }, self)

    return row
end

function Row.is_row(row)
    return getmetatable(row) == Row
end

function Row:set_columns(columns)
    self._columns = vim.tbl_map(function(options)
        return Column:new(options[1], options)
    end, columns)
end

function Row:column(idx)
    vim.print(self._columns)
    vim.print(self._columns[idx])
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
