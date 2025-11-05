local log_command = {}

local compat = require("parcel.compat")
local log = require("parcel.log")

function log_command.run(options)
    local log_path = log.default_logger():path()
    local result = compat.uv.fs_lstat(log_path:absolute())

    -- TODO: How to detect failure here?
    if not result then
        require("parcel.notify").warn("No log exists yet")
        return
    end

    vim.cmd(("%s split %s"):format(options.mods, log_path:absolute()))
end

return log_command
