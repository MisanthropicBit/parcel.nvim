local parcel = {}

local config = require("parcel.config")

---@class parcel.SetupConfiguration
---@field options parcel.Config

---@param configuration parcel.SetupConfiguration
function parcel.setup(configuration)
    -- TODO: Replace with validation from config module
    vim.validate({ configuration = { configuration, "table" } })

    config.setup(configuration.options)

    -- TODO: Perhaps don't use a global variable?
    vim.g.parcel_loaded = true
end

return parcel
