local lockfile_command = {}

local Path = require("parcel.path")

function lockfile_command.run(options)
    local lockfile_path = Path:new(vim.fn.stdpath("data"), "parcel.lock.json")

    -- TODO: Check that file exists

    vim.cmd(("%s split %s"):format(options.mods, lockfile_path:absolute()))
end

return lockfile_command
