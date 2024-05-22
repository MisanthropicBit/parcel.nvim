--- A task is a light wrapper around a function that will be run asynchronously
---@class parcel.Task
---@field private _func function
---@field private _coroutine thread?
---@field private _start_time number
---@field private _end_time number
---@field private _failed boolean
---@field private _cancelled boolean
local Task = {}

local async = require("parcel.tasks.async")

--- Create and immediately run an asynchronous task
---@param func_or_task function | parcel.Task
---@param callback parcel.async.Callback?
---@param ... unknown any extra arguments for the initial invocation of the task
---@return parcel.Task
function Task.run(func_or_task, callback, ...)
    return async.run(func_or_task, callback, ...)
end

--- Create a new task
---@param func function
---@return parcel.Task
function Task.new(func)
    if func == nil or type(func) ~= "function" then
        error(("Expected a function for creating task, got '%s'"):format(func))
    end

    local task = setmetatable({}, { __index = Task })

    task._func = func
    task._coroutine = coroutine.create(func)
    task._start_time = nil
    task._end_time = nil
    task._failed = false
    task._cancelled = false

    return task
end

---@return thread?
function Task:coroutine()
    return self._coroutine
end

function Task:start(callback)
    if self:started() then
        error("Attempt to start task that was already started")
    end

    self._start_time = vim.loop.hrtime()

    async.run(self._func, function(success, results)
        self._end_time = vim.loop.hrtime()

        if not success then
            self._failed = true
        end

        if callback then
            callback(success, results)
        end
    end)
end

---@return boolean
function Task:failed()
    return self._failed
end

---@return boolean
function Task:cancelled()
    return self._cancelled
end

---@return boolean
function Task:started()
    return self._start_time ~= nil
end

---@return boolean
function Task:done()
    return self._end_time ~= nil
end

function Task:cancel()
    if self:cancelled() then
        error("Attempt to cancel task that was already cancelled")
    end

    self._cancelled = true
end

--- Return the elapsed time in milliseconds or the total duration of the task
--- if done. Returns -1 if the task has not been started yet.
---@return number
function Task:elapsed()
    if not self:started() then
        return -1
    end

    local elapsed = self._end_time == nil and vim.loop.hrtime() or self._end_time

    return (elapsed - self._start_time) / 1000
end

return Task
