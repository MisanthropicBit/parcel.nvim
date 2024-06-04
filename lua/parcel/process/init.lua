local process = {}

local uv = vim.loop

---@class parcel.ProcessOptions
---@field args string[]?
---@field cwd string?
---@field on_exit fun(ok: boolean, result: any, code: integer, signal: integer?)
---@field stdin uv_stream_t?
---@field timeout integer?

local signals = {
    sigint = "sigint",
}

local function create_on_read_handler(result, stdio)
    return function(err, data)
        if data then
            local sub, _ = data:gsub("\r\n", "\n")
            table.insert(result[stdio], sub)
        end
    end
end

--- Spawn a process
---@param command string
---@param options parcel.ProcessOptions?
---@return uv_process_t|nil
function process.spawn(command, options)
    local stdout = uv.new_pipe()
    local stderr = uv.new_pipe()
    local handle = nil
    local pid = nil
    local result = {
        stdout = {},
        stderr = {},
    }
    local _options = options or {}
    local stdin

    if _options.stdin then
        stdin = uv.new_pipe()
    end

    handle, pid = uv.spawn(command, {
        stdio = { stdin, stdout, stderr },
        args = _options.args,
        cwd = _options.cwd,
    }, function(code, signal)
        handle:close()
        stdout:close()
        stderr:close()

        if stdin then
            stdin:close()
        end

        local on_exit = _options.on_exit

        if on_exit and type(on_exit) == "function" then
            on_exit(code == 0, result, code, signal)
        end
    end)

    uv.read_start(stdout, create_on_read_handler(result, "stdout"))
    uv.read_start(stderr, create_on_read_handler(result, "stderr"))

    if _options.stdin then
        uv.write(stdin, _options.stdin)

        uv.shutdown(stdin, function()
            if handle then
                uv.close(handle)
            end
        end)
    end

    return handle
end

function process.kill(handle)
    if handle and not handle:is_closing() then
        process.running[handle] = nil
        uv.process_kill(handle, signals.sigint)

        return true
    end

    return false
end

function process.kill_all()
    for handle in pairs(process.running) do
        process.kill(handle)
    end
end

return process
