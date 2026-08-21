local sources = {}

local validators = require("parcel.sources.validators")

---@alias parcel.SectionResult { [1]: string, [2]: string }[]

--- The interface for plugins that retrieve parcels from some source
---@class parcel.Source
---@field name               fun(): string
---@field handle_open        async fun(parcel: parcel.Parcel, value: unknown, open_type: string): boolean
---@field write_section      fun(parcel: parcel.Parcel, section: parcel.ui.Lines): parcel.SectionResult
---@field has_update         async fun(parcel: parcel.Parcel): parcel.Parcel?

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

---@param source_type string | parcel.SourceType
---@return parcel.Source?
function sources.resolve_source(source_type)
    local ok, source = pcall(sources.get_source, source_type)

    if not ok then
        return
    end

    ---@cast source parcel.Source
    return source
end

return sources
