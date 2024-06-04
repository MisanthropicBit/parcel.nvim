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
---@field sources table<string, parcel.Spec>

local function resolve_specs(source_name, specs)
    local ok, source = pcall(sources.get_source, source_name)

    if not ok then
        notify.log.error(source)
        return
    end

    ---@cast source parcel.Source

    local supported, reason = source.supported()

    if not supported then
        notify.log.error("Source '%s' is not supported: %s", source_name, reason)
        return
    end

    log.info("Validating specs for source '%s'", source_name)

    local spec_errors = 0

    for _, raw_spec in ipairs(specs) do
        local spec = Spec:new(raw_spec, source_name)
        spec:validate()

        if #spec:errors() > 0 then
            spec_errors = spec_errors + #spec:errors()
        end

        -- TODO: Change config._parcels to state.parcels()
        state.add_parcel(Parcel:new({ spec = spec }))
    end

    if spec_errors > 0 then
        notify.log.error(
            "Found %d parcel specification error(s) for source '%s'",
            spec_errors,
            source.name()
        )
    end
end

---@param configuration parcel.SetupConfiguration
function parcel.setup(configuration)
    -- TODO: Replace with validation from config module
    vim.validate({ configuration = { configuration, "table" } })

    config.setup(configuration.options)

    if type(configuration.sources) ~= "table" then
        notify.log.error("config.sources is not a table")
        return
    end

    for source_name, specs in pairs(configuration.sources) do
        resolve_specs(source_name, specs)
    end

    if #state.parcels() > 0 then -- and config.autoinstall == true then
        log.info("Autoinstalling parcels")
        actions.install_missing(state.parcels())
    end
end

return parcel
