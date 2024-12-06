local sources = {}

local validators = require("parcel.sources.validators")

---@class parcel.SourceNoSupport
---@field supported false
---@field reason string

---@class parcel.SourceSupported
---@field supported true
---@field reason nil

---@alias parcel.SourceSupportResult parcel.SourceSupported | parcel.SourceNoSupport

---@class parcel.SourceSupport
---@field general parcel.SourceSupportResult

--- The interface for plugins that retrieve parcels from some source
---@class parcel.Source
---@field name fun(): string
---@field configuration_keys fun(): table<string, parcel.SourceConfigKey>
---@field validate fun(parcel: parcel.Parcel, keys: table<string, any>): boolean
---@field supported async fun(): parcel.SourceSupport
---@field write_section fun(parcel: parcel.Parcel, section: parcel.Lines)
---@field install async fun(parcel: parcel.Parcel, context: table?)
---@field update async fun(parcel: parcel.Parcel, context: table?)
---@field uninstall async fun(parcel: parcel.Parcel, context: table?)

---@class parcel.SourceConfigKey
---@field name string
---@field expected_types string[]
---@field required boolean?
---@field validator fun(value: any, keys: string[])

---@enum parcel.SourceType
sources.Source = {
    git = "git",
    luarocks = "luarocks",
    dev = "dev",
}

---@return table<string, parcel.SourceConfigKey>
function sources.common_configuration_keys()
    return {
        version = {
            name = "version",
            expected_types = { "string" }, -- TODO: Add version validation
        },
        pin = {
            name = "pin",
            expected_types = { "boolean" },
        },
        disable = {
            name = "disable",
            expected_types = { "boolean" }
        },
        condition = {
            name = "condition",
            expected_types = { "function" },
        },
        dependencies = {
            name = "dependencies",
            expected_types = { "table" },
            validator = validators.is_list,
        },
        config = {
            name = "config",
            expected_types = { "function", "string" },
        },
    }
end

---@param source_type string | parcel.SourceType
---@return parcel.Source?
function sources.get_source(source_type)
    if not sources.Source[source_type] then
        error(("Source '%s' does not exist"):format(source_type))
    end

    return require("parcel.sources." .. source_type)
end

---@async
---@param source_type string | parcel.SourceType
---@return boolean
---@return parcel.Source | string?
function sources.resolve_source(source_type)
    local ok, source = pcall(sources.get_source, source_type)

    if not ok then
        return ok, source
    end

    ---@cast source parcel.Source

    local supported, reason = source.supported()

    if not supported then
        return false, reason
    end

    return true, source
end

return sources
