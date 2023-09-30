---@class parcel.PackspecDescription
---@field summary? string
---@field detailed? string
---@field homepage? string
---@field license? string

---@class parcel.ExternalDependency
---@field name string
---@field version string

--- A package specification of a neovim plugin
---@class parcel.Packspec
---@field name string?
---@field package string
---@field source string
---@field version? string
---@field specification_version string
---@field description? parcel.PackspecDescription
---@field dependencies parcel.Dependency[]
---@field external_dependencies parcel.ExternalDependency[]
local Packspec = {
    _packspec = nil
}

local required_properties = {
    "package",
    "source",
}

function Packspec.from_json_string(value)
    local packspec = Packspec.new(vim.json.decode(value))
    Packspec.validate(packspec)

    return packspec
end

---@return parcel.Packspec
function Packspec:new(raw_packspec)
    Packspec.validate(raw_packspec)

    local defaults = {
        package = nil,
        version = nil,
        specification_version = nil,
        source = nil,
        description = {
            summary = nil,
            detailed = nil,
            homepage = nil,
            license = nil,
        },
        dependencies = {},
        external_dependencies = {},
    }

    local packspec = vim.tbl_deep_extend("force", defaults, raw_packspec)

    return setmetatable(packspec, { __index = self })
end

function Packspec.validate(packspec)
    for _, prop in ipairs(required_properties) do
        assert(
            packspec[prop],
            ("Missing required property '%s' in packspec"):format(prop)
        )
    end
end

return Packspec
