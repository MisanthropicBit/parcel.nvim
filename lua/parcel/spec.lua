local sources = require("parcel.sources")

--- A user specification of a parcel as passed to the setup function
---@class parcel.Spec
---@field private _name string name of the spec
---@field private _source string source type
---@field private _raw_spec table
---@field private _validated boolean
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
    _name = "",
    pinned = false,
    disabled = false,
    dev = false,
}

Spec.__index = Spec

---@return parcel.Spec
function Spec:new(raw_spec, source)
    local spec_name = type(raw_spec) == "string" and raw_spec or raw_spec[1]

    return setmetatable({
        _name = spec_name,
        _source = source,
        _raw_spec = raw_spec,
        _errors = {},
        _validated = false,
    }, Spec)
end

---@return string
function Spec:name()
    return self._name
end

---@return string
function Spec:source_name()
    return self._source
end

---@return string[]
function Spec:errors()
    return self._errors
end

---@param message string
---@param context table?
---@param ... unknown
function Spec:push_error(message, context, ...)
    table.insert(self._errors, {
        message = message:format(...),
        context = context,
    })
end

---@return boolean
function Spec:validated()
    return self._validated
end

---@return boolean
---@return string[]?
function Spec:validate()
    local ok, source = pcall(sources.get_source, self._source)

    if not ok then
        self:push_error("Source '%s' is not supported", nil, self._source)
        return false, self:errors()
    end

    ---@cast source parcel.Source

    local raw_spec = self._raw_spec

    if type(raw_spec) == "string" then
        return true, self:errors()
    end

    if type(raw_spec) ~= "table" then
        self:push_error("Expected string or table, got '%s", nil, type(raw_spec))
        return false, self:errors()
    end

    if type(raw_spec[1]) ~= "string" then
        self:push_error("Expected parcel name as first table element")
        return false, self:errors()
    end

    local config_keys = vim.tbl_extend(
        "force",
        source.configuration_keys(),
        sources.common_configuration_keys()
    )

    -- Check each key and value in the raw user spec
    for key, value in pairs(raw_spec) do
        if key == 1 then
            goto continue
        end

        local key_spec = config_keys[key]

        if key_spec == nil then
            self:push_error(
                "Unknown configuration key '%s' for source '%s",
                nil,
                key,
                source.name()
            )
        else
            if key_spec.expected_types then
                if not vim.tbl_contains(key_spec.expected_types, type(value)) then
                    self:push_error(
                        "Expected type(s) %s for key %s but got type %s",
                        nil,
                        table.concat(key_spec.expected_types, ", "),
                        key,
                        type(value)
                    )
                end
            end

            if key_spec.validator then
                local valid, err = key_spec.validator(value)

                if not valid then
                    self:push_error("Key %s failed validation: %s", nil, key, err)
                end
            end
        end

        :: continue ::
    end

    -- Check required keys
    for key, value in pairs(config_keys) do
        if value.required and not raw_spec[key] == nil then
            self:push_error("Missing required key %s in spec", nil, key)
        end
    end

    local errors = self:errors()
    self._validated = #errors == 0

    return #errors == 0, self:errors()
end

function Spec:get(key)
    return self._raw_spec[key]
end

return Spec
