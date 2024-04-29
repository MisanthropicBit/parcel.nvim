local Text = {}

local text_defaults = {}

function Text:new(args)
    local text = vim.tbl_deep_extend('force', text_defaults, args)
    self.__index = self

    return setmetatable(text, self)
end

return Text
