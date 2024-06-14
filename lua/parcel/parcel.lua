local config = require("parcel.config")
local utils = require("parcel.utils")
-- local version = require("parcel.version")

---@class parcel.ParcelError
---@field message string
---@field context table?

---@class parcel.Parcel
---@field issues_url? string
---@field pulls_url? string
---@field source_type string
---@field dependencies? parcel.Dependency[]
---@field packspec? parcel.Packspec
---@field private _spec parcel.Spec
---@field private _name string
---@field private _state parcel.State
---@field private _license? string
---@field private _source? string
---@field private _description? string
---@field private _external_dependencies? parcel.ExternalDependency[]
---@field private _highlight table
---@field private _errors parcel.ParcelError[]
local Parcel = {
    issues_url = nil,
    pulls_url = nil,
}

Parcel.__index = Parcel

---@enum parcel.State
Parcel.State = {
    Installed = "Installed",
    NotInstalled = "NotInstalled",
    Updating = "Updating",
    UpdatesAvailable = "UpdatesAvailable",
    Failed = "Failed",
}

---@type parcel.Parcel
local parcel_defaults = {
    url = nil,
    issues_url = nil,
    pulls_url = nil,
    _state = Parcel.State.NotInstalled,
    _errors = {},
}

function Parcel:new(args)
    -- if parcel.version then
    --     parcel.version = vim.version.parse(parcel.version)
    -- end

    local spec = args.spec or {}

    return setmetatable(vim.tbl_extend("force", parcel_defaults, {
        _highlight = {},
        _spec = spec,
        _cleaned_name = nil,
    }), Parcel)
end

---@param error string
---@param context table?
function Parcel:push_error(error, context)
    self:set_state(Parcel.State.Failed)

    table.insert(self._errors, {
        message = error,
        context = context,
    })
end

function Parcel:errors()
    return self._errors
end

function Parcel:iter_dependencies()
    ---@diagnostic disable-next-line: undefined-field
    return ipairs(self.dependencies)
end

function Parcel:iter_ext_dependencies()
    ---@diagnostic disable-next-line: undefined-field
    return ipairs(self:external_dependencies())
end

---@return parcel.Spec
function Parcel:spec()
    -- TODO: Copy spec or set metatable to disallow mutation
    return self._spec
end

function Parcel:spec_errors()
    return self._spec:errors()
end

function Parcel:state()
    return self._state
end

---@param new_state parcel.State
function Parcel:set_state(new_state)
    self._state = new_state
end

---@return string
function Parcel:name()
    return self.packspec and self.packspec.package or self._spec.name
end

function Parcel:clean_name()
    if not self._spec:validated() then
        return nil
    end

    return utils.clean_parcel_name(self._spec:name())
end
    
function Parcel:pinned()
    return self._pinned
end

function Parcel:toggle_pinned()
    self._pinned = not self._pinned
end

function Parcel:disabled()
    return self._disabled
end

function Parcel:toggle_disabled()
    self._disabled = not self._disabled
end

function Parcel:local_development()
    return self._dev
end

function Parcel:source()
    return self.packspec and self.packspec.repository.type or self._spec._source
end

function Parcel:version()
    return self.packspec and self.packspec.package or self._spec.version
end

function Parcel:license()
    return self.packspec and self.packspec.description or nil
end

function Parcel:description()
    return self.packspec and self.packspec.description.summary or nil
end

function Parcel:dependencies()
    return self.packspec and self.packspec.dependencies or {}
end

function Parcel:external_dependencies()
    return self.packspec and self.packspec.external_dependencies or {}
end

function Parcel:__newindex(key, value)
    if key:sub(1, 1) ~= "_" then
        error("Cannot mutate parcel")
    end
end

return Parcel
