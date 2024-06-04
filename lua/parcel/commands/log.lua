local log_command = {}

local log = require("parcel.log")

function log_command.run(options)
    local log_path = log.default_logger():path()

    vim.cmd(("%s split %s"):format(options.mods, log_path:absolute()))
end

return log_command
