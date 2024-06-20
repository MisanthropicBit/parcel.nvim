local lockfile_command = {}

local compat = require("parcel.compat")
local notify = require("parcel.notify")
local Path = require("parcel.path")

function lockfile_command.run(options)
    local lockfile_path = Path:new(vim.fn.stdpath("data"), "parcel.lock.json")
    local result = compat.loop.fs_lstat(lockfile_path:absolute())

    -- TODO: How to detect failure here?
    if not result then
        notify.warn("No lockfile exists yet")
        return
    end

    vim.cmd(("%s split %s"):format(options.mods, lockfile_path:absolute()))
end

return lockfile_command
