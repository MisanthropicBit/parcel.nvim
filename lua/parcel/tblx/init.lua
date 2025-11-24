local tblx = {}

---@generic T
---@param size integer
---@param value T
---@return T[]
function tblx.fill_list(size, value)
    local result = {}

    for idx = 1, size do
        table.insert(result, value)
    end

    return result
end

return tblx
