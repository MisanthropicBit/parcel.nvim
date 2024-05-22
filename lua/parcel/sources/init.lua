local sources = {}

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
---@field supported async fun(): parcel.SourceSupport
---@field install async fun(parcel: parcel.Parcel, context: table?): parcel.Task

---@class parcel.SourceConfigKey
---@field name string
---@field expected_types (string | fun(key: any): boolean)[]
---@field optional boolean?

---@enum parcel.SourceType
sources.Source = {
    git = "git",
    luarocks = "luarocks",
    dev = "dev",
}

---@return table<string, parcel.SourceConfigKey>
function sources.common_configuration_keys()
    return {
        {
            name = "version",
            expected_types = { "string" }, -- TODO: Add version validation
        },
        {
            name = "pin",
            expected_types = { "boolean" },
        },
        {
            name = "disable",
            expected_types = { "boolean" }
        },
        {
            name = "condition",
            expected_types = { "function" },
        },
        {
            name = "dependencies",
            expected_types = { vim.tbl_islist },
        }
    }
end

---@param source string | parcel.SourceType
---@return parcel.Source?
function sources.get_source(source)
    if not sources.Source[source] then
        error(("Source '%s' does not exist"):format(source))
    end

    return require("parcel.sources." .. source)
end

return sources
