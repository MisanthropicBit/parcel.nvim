local config = require("parcel.config")
-- local version = require("parcel.version")

---@enum parcel.State
local State = {
    installed = "installed",
    not_installed = "not_installed",
    updating = "updating",
    updates_available = "updates_available",
    failed = "failed",
}

---@class parcel.Parcel
---@field _name string
---@field _state parcel.State
---@field issues_url? string
---@field pulls_url? string
---@field _version? string
---@field _license? string
---@field _source? string
---@field source_type string
---@field _description? string
---@field dependencies? parcel.Dependency[]
---@field _external_dependencies? parcel.ExternalDependency[]
---@field spec parcel.Spec
---@field packspec? parcel.Packspec
---@field _highlight table

local Parcel = {
    issues_url = nil,
    pulls_url = nil,
}

---@type parcel.Parcel
local parcel_defaults = {
    url = nil,
    issues_url = nil,
    pulls_url = nil,
    _state = State.not_installed
}

function Parcel:new(args)
    local parcel = vim.tbl_deep_extend("force", parcel_defaults, args)
    -- parcel.packspec = nil
    parcel._highlight = {}
    self.__index = self

    -- if parcel.version then
    --     parcel.version = vim.version.parse(parcel.version)
    -- end

    return setmetatable(parcel, self)
end

function Parcel:set_error(error)
    self._state = State.failed
    self._error = error
end

function Parcel:iter_dependencies()
    ---@diagnostic disable-next-line: undefined-field
    return ipairs(self.dependencies)
end

function Parcel:iter_ext_dependencies()
    ---@diagnostic disable-next-line: undefined-field
    return ipairs(self:external_dependencies())
end

function Parcel:state()
    return self._state
end

function Parcel:set_state(new_state)
    self._state = new_state
end

function Parcel:name()
    return self.packspec and self.packspec.package or self.spec.name
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
    return self.packspec and self.packspec.repository.type or self.spec.source
end

function Parcel:version()
    return self.packspec and self.packspec.package or self.spec.version
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
