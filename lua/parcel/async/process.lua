local async_process = {}

local process = require("parcel.process")
local Task = require("parcel.tasks")

---@class parcel.async.ProcessOptions
---@field args string[]?
---@field cwd string?
---@field stdin uv_stream_t?
---@field timeout integer?

local spawn = Task.wrap(function(command, options, callback)
    local _options = options or {}
    _options.on_exit = callback

    process.spawn(command, _options)
end, 3)

--- Spawn a process asynchronously and wait for it to finish
---@param command string
---@param options parcel.async.ProcessOptions?
---@return parcel.Task
function async_process.spawn_and_wait(command, options)
    return spawn(command, options)
end

--- Return a task that spawns a process asynchronously
---@param command string
---@param options parcel.async.ProcessOptions?
---@return parcel.Task
function async_process.spawn(command, options)
    return Task.run(function()
        return async_process.spawn_and_wait(command, options)
    end)
end

return async_process
