local update = {}

local tblx = require("parcel.tblx")

---@param user_spec parcel.Spec
---@param source parcel.Source
---@param installed_parcel parcel.Parcel
---@return boolean
function update.update_parcel(user_spec, source, installed_parcel)
    local spec_diff = tblx.diff(installed_parcel:spec(), user_spec)

    if vim.tbl_count(spec_diff) == 0 then
        return false
    end

    -- Spec was updated, validate it again
    local ok, errors = user_spec:validate()

    if not ok then
        return false
    end

    -- installed_parcel:set_spec(new_spec)
    local update_ok = pcall(source.update, installed_parcel, { spec_diff = spec_diff })

    if not update_ok then
        return false
    end

    return true
end

return update
