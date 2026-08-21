local parcel = {}

local parcel_loaded = false

---@class parcel.SetupConfiguration
---@field options parcel.Config

---@param configuration parcel.Config
function parcel.setup(configuration)
    if parcel_loaded then
        return
    end

    require("parcel.config").setup(configuration)

    -- TODO: Move elsewhere, no need to load already
    require("parcel.diagnostics").setup()
    require("parcel.state").setup()
    require("parcel.highlight").setup()

    parcel_loaded = true

    -- require("parcel.log").info("parcel.nvim initialized")
end

return parcel
