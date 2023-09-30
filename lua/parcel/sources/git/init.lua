local M = {}

---@param parcel parcel.Parcel
function M.url_from_parcel(parcel)
    return (nil or "https://github.com/") .. parcel.name
end

return M
