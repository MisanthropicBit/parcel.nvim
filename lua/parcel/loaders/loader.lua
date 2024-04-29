local config = require("parcel.config")
local version = require("parcel.version")

local Loader = {}

---@class parcel.Loader
---@field name string
---@field source string
---@field url? string
---@field url_issues? string
---@field url_pull_requests? string
---@field state "running" | "done" | "cancelled"
---@field version? string
---@field declared_version? string
---@field license? string
---@field description string
---@field pinned boolean
---@field disabled boolean
---@field dev boolean
---@field dependencies parcel.Dependency[]
---@field external_dependencies parcel.Dependency[]

---@type parcel.Loader
local loader_defaults = {
    name = '',
    source = '',
    url = nil,
    url_issues = nil,
    url_pull_requests = nil,
    state = { value = "not_installed" },
    version = nil,
    declared_version = nil,
    license = nil,
    description = '',
    pinned = false,
    disabled = false,
    dev = false,
}

function Loader:new(args)
    local loader = vim.tbl_deep_extend('force', loader_defaults, args)
    self.__index = self

    return setmetatable(loader, self)
end

function Loader:prepare(parcel)
    
end

function Loader:run()
end

return Loader
