local utils = require("parcel.utils")

---@class parcel.ParcelError
---@field message string
---@field context table?

---@class parcel.Parcel
---@field private _source_type string
---@field private _plugdata? vim.pack.PlugData
---@field private _state parcel.State
---@field private _errors parcel.ParcelError[]
local Parcel = {}

Parcel.__index = Parcel

---@enum parcel.State
Parcel.State = {
    Active = "active",
    Inactive = "inactive",
    Updating = "updating",
    UpdatesAvailable = "updates_available",
    Failed = "failed",
}

---@type parcel.Parcel
local parcel_defaults = {
    _source_type = "git",
    _errors = {},
}

function Parcel:new(args)
    local spec = args.spec or {}

    return setmetatable(vim.tbl_extend("force", parcel_defaults, {
        _highlight = {},
        _plugdata = spec,
        _state = Parcel.State.Inactive,
        _errors = {},
    }), Parcel)
end

---@param error string
---@param context table?
function Parcel:push_error(error, context)
    -- self:set_state(Parcel.State.Failed)

    table.insert(self._errors, {
        message = error,
        context = context,
    })
end

function Parcel:errors()
    return self._errors
end

---@return vim.pack.Spec?
function Parcel:spec()
    return self._plugdata and self._plugdata.spec or {}
end

function Parcel:active()
    return self._plugdata.active or false
end

function Parcel:revision()
    return self._plugdata.rev
end

---@return string
function Parcel:name()
    return self:spec().name
end

---@return string
function Parcel:source_url()
    return self:spec().src
end

---@return string
function Parcel:path()
    return self._plugdata.path
end

---@return string | vim.VersionRange
function Parcel:version()
    return self:spec().version
end

---@return boolean
function Parcel:pinned()
    return utils.git.is_sha(self:version())
end

---@return boolean
function Parcel:disabled()
    return false
end

function Parcel:source()
    return "git"
end

function Parcel:state()
    return self._state
end

---@param state parcel.State
function Parcel:set_state(state)
    self._state = state
end

function Parcel:__newindex(key, value)
    if key:sub(1, 1) ~= "_" then
        error("Cannot mutate parcel")
    end
end

return Parcel
