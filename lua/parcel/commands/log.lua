local log_command = {}

---@param options vim.api.keyset.create_user_command.command_args
function log_command.run(options)
    local log_path = require("parcel.log").default_logger():path():absolute()
    local ok, result_or_err, error_name = vim.uv.fs_stat(log_path)

    if not ok then
        require("parcel.notify").warn("No log file exists yet")
        return
    end

    vim.cmd(("%s split %s"):format(options.mods, log_path))
end

return log_command
