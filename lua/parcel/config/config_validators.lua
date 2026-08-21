local config_validators = {}

local function is_positive_non_zero_number(value)
    return type(value) == "number" and value > 0
end

config_validators.is_positive_non_zero_number_validator =
    { is_positive_non_zero_number, "a positive, non-zero number" }

---@param tbl table
function config_validators.table_value_validator(tbl)
    return {
        ---@param value unknown
        ---@return boolean
        function(value)
            for _, tbl_value in pairs(tbl) do
                if value == tbl_value then
                    return true
                end
            end

            return false
        end,
        ("to be one of %s"):format(vim.tbl_values(tbl))
    }
end

return config_validators
