local config = require("parcel.config")
local version = require("parcel.version")

local loader = {}

---@param parcel parcel.Parcel
function loader:reload_parcel(parcel)
    -- TODO: Get the "cleaned" name of the parcel for lookup
    -- package.loaded[parcel]
end

return loader
