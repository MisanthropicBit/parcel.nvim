local sources = require("parcel.sources")

--- A user specification of a parcel as passed to the setup function
---@class parcel.Spec
---@field name string name of the spec
---@field _source string source type
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

Spec.__index = Spec

---@return parcel.Spec
function Spec:new(raw_spec, source)
    local spec_name = type(raw_spec) == "string" and raw_spec or raw_spec[1]

    return setmetatable({
        name = spec_name,
        _source = source,
        _raw_spec = raw_spec,
        _errors = {},
    }, Spec)
end

---@return string[]
function Spec:errors()
    return self._errors
end

function Spec:push_error(err, ...)
    table.insert(self._errors, err:format(...))
end

function Spec:validate()
    local ok, source = pcall(sources.get_source, self._source)

    if not ok then
        self:push_error("Source '%s' is not supported", self._source)
        return false
    end

    ---@cast source parcel.Source

    local raw_spec = self._raw_spec

    if type(raw_spec) == "string" then
        return true
    end

    if type(raw_spec) ~= "table" then
        self:push_error("Expected string or table, got '%s", type(raw_spec))
        return false
    end

    if type(raw_spec[1]) ~= "string" then
        self:push_error("Expected parcel name as first table element")
        return false
    end

    local config_keys = source.configuration_keys()

    -- for key, _ in pairs(raw_spec) do
    --     if key ~= 1 then
    --         if not vim.tbl_contains(config_keys, key) then
    --             self:push_error("Unknown configuration key '%s'", key)
    --             return false
    --         end
    --     end
    -- end
end

function Spec:get(key)
    return self._raw_spec[key]
end

return Spec
