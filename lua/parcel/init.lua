local parcel = {}

local actions = require("parcel.actions")
local config = require("parcel.config")
local log = require("parcel.log")
local notify = require("parcel.notify")
local state = require("parcel.state")
local sources = require("parcel.sources")
local Parcel = require("parcel.parcel")
local Spec = require("parcel.spec")
local utils = require("parcel.utils")

---@class parcel.UserSpec
---@field git? (string | parcel.Spec)[]
---@field luarocks? (string | parcel.Spec)[]

---@class parcel.SetupConfiguration
---@field options parcel.Config
---@field sources table<parcel.SourceType, parcel.Spec[]>

---@param configuration parcel.SetupConfiguration
function parcel.setup(configuration)
    -- TODO: Replace with validation from config module
    vim.validate({ configuration = { configuration, "table" } })

    config.setup(configuration.options)

    if type(configuration.sources) ~= "table" then
        notify.log.error("config.sources is not a table")
        return
    end

    -- TODO: Perhaps don't use a global variable?
    vim.g.parcel_loaded = true

    actions.update_parcels(configuration.sources)
end

return parcel
