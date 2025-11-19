local parcel = {}

local parcel_loaded = false

---@class parcel.SetupConfiguration
---@field options parcel.Config

---@param configuration parcel.SetupConfiguration
function parcel.setup(configuration)
    if parcel_loaded then
        return
    end

    -- TODO: Replace with validation from config module
    -- vim.validate({ configuration = { configuration, "table" } })

    -- require("parcel.config").setup(configuration.options)
    require("parcel.diagnostics").setup()
    require("parcel.state").setup()

    parcel_loaded = true
end

return parcel
