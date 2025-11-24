local compat = {}

---@param feature string
---@return boolean
function compat.has(feature)
    return vim.fn.has(feature) == 1
end

return compat
