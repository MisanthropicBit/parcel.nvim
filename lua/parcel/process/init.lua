local process = {}

local uv = vim.loop

local signals = {}

local function create_on_read_handler(result, stdio)
    return function(err, data)
        if data then
            local sub, _ = data:gsub("\r\n", "\n")
            table.insert(result[stdio], sub)
        end
    end
end

function process.spawn(command, options)
    local stdin = uv.new_pipe()
    local stdout = uv.new_pipe()
    local stderr = uv.new_pipe()
    local handle = nil
    local pid = nil
    local result = {
        stdout = {},
        stderr = {},
    }

    handle, pid = uv.spawn(command, {
        stdio = { stdin, stdout, stderr },
        args = options.args,
        cwd = options.cwd,
    }, function(code, signal)
        handle:close()
        stdin:close()
        stdout:close()
        stderr:close()

        local on_exit = options.on_exit

        if on_exit and type(on_exit) == "function" then
            on_exit(code == 0, result, code, signal)
        end
    end)

    vim.print(handle, pid)

    uv.read_start(stdout, create_on_read_handler(result, "stdout"))
    uv.read_start(stderr, create_on_read_handler(result, "stderr"))

    if options.stdin then
        uv.write(stdin, options.stdin)

        uv.shutdown(stdin, function()
            uv.close(handle, function()
                print("process closed", handle, pid)
            end)
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
