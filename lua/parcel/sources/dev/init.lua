---@type parcel.Source
local dev_source = {}

local config = require("parcel.config")
local async = require("parcel.async")
local Path = require("parcel.path")

function dev_source.name()
    return "dev"
end

function dev_source.configuration_keys()
    return {}
end

function dev_source.supported()
    -- Local development source is always supported
    return {
        general = { true }
    }
end

function dev_source.install(parcel)
    local path = parcel:name()
    local stat = async.fs.stat(path)

    -- TODO: Check stat

    local access = async.fs.access(path, "R")

    if not access then
        parcel:set_error("Cannot access")
        return
    end

    vim.opt.runtimepath:append(path)
end

return dev_source
