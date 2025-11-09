---@class parcel.Cell
---@field value string
---@field align ("left" | "center" | "right")?
---@field lpad integer
---@field rpad integer
local Cell = {
    align = "left",
    lpad = 0,
    rpad = 0,
    len = 0,
    byte_size = 0,
}

Cell.__index = Cell

---@class parcel.CellOptions
---@field [1] boolean | string
---@field align ("left" | "center" | "right")?
---@field lpad integer?
---@field rpad integer?
---@field icon string?

---@param options parcel.CellOptions
---@return parcel.Cell
function Cell.new(options)
    local value = options[1]
    local cell = setmetatable(options, Cell)

    if type(value) == "boolean" then
        assert(options.icon, "Missing 'icon' field for boolean cell")
        cell.value = value and options.icon or " "
        cell:set_value(value and options.icon or " ")
    else
        cell:set_value(value)
    end

    return cell
end

--- Return the column's width in characters
---@return integer
function Cell:size()
    return self.lpad + self.rpad + vim.fn.strwidth(self.value)
end

--- Return the cell's width in bytes
---@return integer
function Cell:bytesize()
    return self.byte_size
end

---@param value string
function Cell:set_value(value)
    self.value = value
    -- self._size = vim.fn.strwidth(value)
    -- self.byte_size = vim.fn.strlen(value)
end

---@param max_width integer
---@return string
function Cell:render(max_width)
    -- FIX: Method needs cleanup, padding is wrong
    local result = {}
    local padding = max_width - self:size()
    vim.print(vim.inspect({ "max_width", max_width, "padding", padding }))
    local align = self.align or nil

    -- First apply padding according to the maximum column width
    if align == "right" then
        vim.list_extend(result, { (" "):rep(padding), self.value })
    elseif align == "left" then
        vim.list_extend(result, { self.value, (" "):rep(padding) })
    elseif align == "center" then
        local half_width = padding / 2

        vim.list_extend(
            result,
            { (" "):rep(half_width), self.value, (" "):rep(half_width) }
        )
    -- else
    --     table.insert(result, (" "):rep(padding))
    end

    -- Apply left and right padding
    table.insert(result, 1, (" "):rep(self.lpad))
    table.insert(result, (" "):rep(self.rpad))

    local rendered = table.concat(result)
    vim.print(vim.inspect({ "rendered", ("'%s'"):format(rendered) }))
    self._size = vim.fn.strwidth(rendered)
    self.byte_size = vim.fn.strlen(rendered)

    return rendered
end

return Cell
