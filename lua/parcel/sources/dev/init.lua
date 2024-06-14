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

-- TODO: Return a structure that is put into each parcel instead?
function dev_source.install(parcel)
    local path = parcel:name()
    local normpath = vim.fs.normalize(path)
    local err, stat = async.fs.stat(normpath)

    if err ~= nil then
        parcel:push_error("Unable to stat local parcel", {
            path = normpath,
        })
        return
    end

    ---@cast stat -nil

    if stat.type ~= "directory" then
        parcel:push_error("Local parcel is not a directory", { path = normpath })
        return
    end

    -- FIX: fs.access doesn't work with directories
    -- local has_access = async.fs.access(normpath, "R")

    -- if not has_access then
    --     parcel:push_error("Cannot read local directory", { path = normpath })
    --     return
    -- end

    async.opt.runtimepath:append(path)
end


function dev_source.update(parcel, context)
    -- Noop
end

function dev_source.uninstall(parcel, context)
    -- TODO: Remove from rtp and unload
end

return dev_source
