local validators = {}

---@param key any
---@return boolean
---@return string?
function validators.is_list(key)
    local is_list = vim.tbl_islist(key)

    return is_list, is_list and nil or "Key is not a list"
end

return validators
