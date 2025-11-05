local compat = {}

---@param feature string
---@return boolean
function compat.has(feature)
    return vim.fn.has(feature) == 1
end

compat.has_extmarks = vim.api.nvim_buf_set_extmark ~= nil
compat.uv = vim.uv or vim.loop

return compat
