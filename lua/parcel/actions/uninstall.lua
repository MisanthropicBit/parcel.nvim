local uninstall = {}

local loader = require("parcel.loader")
local state = require("parcel.state")

---@param source parcel.Source
---@param installed_parcel parcel.Parcel
---@return boolean
function uninstall.uninstall_parcel(source, installed_parcel)
    local ok = pcall(source.uninstall, installed_parcel)

    if not ok then
        return false
    end

    state.remove_parcel(installed_parcel)
    loader.unload_parcel(installed_parcel)

    return true
end

return uninstall
