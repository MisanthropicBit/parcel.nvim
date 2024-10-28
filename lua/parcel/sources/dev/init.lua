---@type parcel.Source
local dev_source = {}

local config = require("parcel.config")
local async = require("parcel.async")
local Path = require("parcel.path")
local Task = require("parcel.tasks")

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

function dev_source.write_section(parcel, section)
    -- Noop
end

-- TODO: Return a structure that is put into each parcel instead?
function dev_source.install(parcel)
    local path = vim.fs.normalize(parcel:name())
    local ok, stat = async.fs.dir_exists(path)

    if not ok then
        parcel:push_error(stat, { path = path })
        return false
    end

    async.opt.runtimepath:append(path)

    return true
end

function dev_source.update(parcel, context)
    -- Noop
end

function dev_source.has_updates(parcel, context)
    return false
end

function dev_source.uninstall(parcel, context)
    local path = vim.fs.normalize(parcel:name())
    async.opt.runtimepath:remove(path)
end

return dev_source
