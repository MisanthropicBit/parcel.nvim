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
---@field name               fun(): string
---@field supported          async fun(): parcel.SourceSupport
---@field write_section      fun(parcel: parcel.Parcel, section: parcel.ui.Lines)
---@field has_update         async fun(parcel: parcel.Parcel, context: table?)
---@field update             async fun(parcel: parcel.Parcel, context: table?)

---@class parcel.SourceConfigKey
---@field name string
---@field expected_types string[]
---@field required boolean?
---@field validator fun(value: any, keys: string[])

---@enum parcel.SourceType
sources.Source = {
    git = "git",
}

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
