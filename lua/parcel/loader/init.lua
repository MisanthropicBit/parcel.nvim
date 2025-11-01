local async = require("parcel.async")
local config = require("parcel.config")

local loader = {}

---@param parcel parcel.Parcel
function loader.reload_parcel(parcel)
    -- TODO: Get the "cleaned" name of the parcel for lookup
    -- package.loaded[parcel]
end

---@param parcel parcel.Parcel
function loader.unload_parcel(parcel)
    local normalized_name = parcel:clean_name()
    ---@cast normalized_name -nil

    -- TODO: Iterate 'lua/' folder instead
    for module in async.fs.iter_modules(parcel:path(), { recursive = true }) do
        package.loaded[module] = nil
        package.preload[module] = nil
    end
end

return loader
