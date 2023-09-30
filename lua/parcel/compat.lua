local compat = {}

---@param feature string
---@return boolean
function compat.has(feature)
    return vim.fn.has(feature) == 1
end

compat.extmarks = vim.api.nvim_buf_set_extmark ~= nil

return compat
