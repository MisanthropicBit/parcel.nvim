---@class parcel.Column
local Column = {
    align = "left",
    lpad = 0,
    rpad = 0,
    min_pad = 0,
    len = 0,
    bytelen = 0,
}

function Column:new(value, options)
    local column = options or {}
    self.__index = self
    setmetatable(column, self)

    if type(value) == "boolean" then
        assert(options.icon, "Missing 'icon' field for boolean column")
        column.value = value and options.icon or " "
        column:set_value(value and options.icon or " ")
    else
        column:set_value(value)
    end

    return column
end

--- Return the column's width in characters
---@return integer
function Column:size()
    return self.lpad + self.value_size + self.rpad + self.min_pad
end

--- Return the column's width in bytes
---@return integer
function Column:bytesize()
    return self.bytelen
end

function Column:set_value(value)
    self.value = value
    self.value_size = vim.fn.strwidth(value)
    self.value_bytesize = vim.fn.strlen(value)
end

---@param max_width integer
---@return string
function Column:render(max_width)
    local result = {}
    local value_width = vim.fn.strwidth(self.value)
    local padding = math.max(max_width.len - value_width, self.min_pad)
    local align = self.align or nil

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
    else
        table.insert(result, (" "):rep(self.lpad) .. self.value .. (" "):rep(self.rpad))
        table.insert(result, (" "):rep(padding))
    end

    local rendered = table.concat(result)
    self.bytelen = vim.fn.strlen(rendered)

    return rendered
end

return Column
