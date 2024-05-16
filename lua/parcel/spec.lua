local sources = require("parcel.sources")

--- A user specification of a parcel as passed to the setup function
---@class parcel.Spec
---@field name string name of the spec
---@field source string source type
---@field branch? string optional branch
---@field version? string optional verison
---@field tag? string optional tag (may be a version too)
---@field pinned? boolean pin branch/tag/version
---@field disabled? boolean
---@field dev? boolean
---@field as? string
---@field url? string
---@field _errors string[]
local Spec = {
    name = "",
    pinned = false,
    disabled = false,
    dev = false,
}

---@return parcel.Spec
function Spec:new(raw_spec, source)
    Spec:validate(raw_spec, source)

    local spec_name = type(raw_spec) == "string" and raw_spec or raw_spec[1]
    local spec = {
        name = spec_name,
        source = source,
        _errors = {},
    }

    setmetatable(spec, { __index = self })

    return spec
end

---@return string[]
function Spec:errors()
    return self._errors
end

function Spec:push_error(err, ...)
    table.insert(self._errors, err:format(...))
end

function Spec:validate(spec, _source)
    local ok, source = pcall(sources.get_source, _source)

    if not ok then
        self:push_error("Source '%s' is not supported", _source)
        return false
    end

    if type(spec) == "string" then
        return true
    end

    if type(spec) ~= "table" then
        self:push_error("Expected string or table, got '%s", type(spec))
        return false
    end

    if type(spec[1]) ~= "string" then
        self:push_error("Expected parcel name as first table element")
        return false
    end

    local config_keys = source.configuration_keys()

    for key, _ in pairs(spec) do
        if not vim.tbl_contains(config_keys, key) then
            self:push_error("Unknown configuration key '%s'", key)
            return false
        end
    end
end

return Spec
