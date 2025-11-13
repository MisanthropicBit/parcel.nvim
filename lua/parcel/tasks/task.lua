-- This file provides convenience functions for easier asynchronous programming
-- that avoids callback hell.
--
-- It uses lua coroutines which suspend when calling an asynchronous function
-- (like vim.loop.fs_stat) and overrides its callback to resume the suspended
-- coroutine, allowing await-style programming.
--
-- The async.wrap function transforms a callback-style asynchronous function
-- into a function that instead uses coroutines to start and resuming when the
-- original callback is invoked.

---@class parcel.task.WaitOptions
---@field concurrency integer? how many tasks can run concurrently at a time
---@field timeout integer? timeout in milliseconds

---@alias parcel.task.Callback fun(ok: boolean, results_or_error: any)

--- Check if we are currently in an async (coroutine) context
local function require_async_context()
    local thread, is_main = coroutine.running()

    if is_main then
        error("Cannot call async function in non-async context")
    end
end

---@param msg string
---@param ... any
local function formatted_error(msg, ...)
    -- TODO: Do not throw here?
    return msg:format(...)
end

--- Handle the callback from an async function
---@param task parcel.Task
---@param callback parcel.async.Callback?
---@param results any
---@param err any
local function handle_callback(task, callback, results, err)
    -- vim.print(vim.inspect(err))
    if callback ~= nil then
        if err == nil then
            callback(true, unpack(results, 2, table.maxn(results)))
        else
            ---@diagnostic disable-next-line: invisible
            task:set_error(err)
            callback(false, err)
        end
    end
end

-- A monotonic counter used for traceability when debugging tasks
local task_id = 1

--- Get a unique task id
---@return integer
local function get_next_task_id()
    local temp = task_id

    task_id = task_id + 1

    return temp
end

--- A task is a wrapper around a function that will be run asynchronously (in a coroutine)
---@class parcel.Task
---@field private _id integer
---@field private _func function
---@field private _coroutine thread?
---@field private _run_callback function?
---@field private _wait_callback function?
---@field private _start_time number
---@field private _end_time number
---@field private _failed boolean
---@field private _cancelled boolean
---@field private _err any
local Task = {}

Task.__index = Task

--- Value returned when a task times out
Task.timeout = "timeout"

function Task.is_task(maybe_task)
    return getmetatable(maybe_task) == Task
end

--- Create and immediately run an asynchronous task
---@param func_or_task function | parcel.Task
---@param callback parcel.task.Callback?
---@param ... unknown any extra arguments for the initial invocation of the task
---@return parcel.Task
function Task.run(func_or_task, callback, ...)
    if Task.is_task(func_or_task) then
        func_or_task:check_state()
    end

    local task = func_or_task

    if type(func_or_task) == "function" then
        task = Task.new(func_or_task)
    end

    ---@cast task parcel.Task

    task:set_callback(callback)
    task:start(...)

    return task
end

-- Wraps a callback-style asynchronous function, returning a function which
-- instead uses coroutines to start and resuming when the original callback is
-- invoked
---@param func function
---@param argc integer argument position of the callback
---@param options { async_only: boolean? }?
---@return function
function Task.wrap(func, argc, options)
    return function(...)
        local _, is_main = coroutine.running()

        if not is_main then
            -- Not in main coroutine, yield back to step function
            local results = { coroutine.yield(argc, func, ...) }

            return unpack(results)
        else
            if options and options.async_only then
                require_async_context()
            end

            -- Allow calling wrapped functions in non-async contexts
            -- TODO: Return from this as well?
            func(...)
        end
    end
end

-- We first define a local wrapped function and call it from Task.sleep so
-- we can add proper documentation to the public function
local sleep = Task.wrap(function(ms, callback)
    vim.defer_fn(callback, ms)
end, 2)

---@param ms number the amount of milliseconds to sleep
function Task.sleep(ms)
    sleep(ms)
end

--- Run a bunch of tasks and wait for them all to complete
local wait_all = Task.wrap(function(tasks, options, callback)
    local done = 0
    local task_idx = 1
    local results = {}
    local _options = options or {}
    local concurrency = options.concurrency or #tasks
    local timeout = _options.timeout or nil
    local timed_out = false
    local running_tasks = {}

    ---@type fun(idx: integer): fun(ok: boolean, result: any)
    local task_callback

    ---@param idx integer
    local function run_next_task(idx)
        if task_idx <= #tasks and not timed_out then
            table.insert(running_tasks, Task.run(tasks[task_idx], task_callback(idx)))
            task_idx = task_idx + 1
        end
    end

    task_callback = function(idx)
        return function(ok, result)
            done = done + 1
            results[idx] = { ok = ok, result = result }

            if timed_out then
                return
            elseif done == #tasks then
                -- Finished all tasks, call callback with the results
                callback(true, results)
            else
                -- There are still tasks to run
                run_next_task(task_idx)
            end
        end
    end

    -- Initially start 'concurrency' number of tasks
    while task_idx <= concurrency do
        run_next_task(task_idx)
    end

    if timeout and #tasks > 0 then
        Task.run(function()
            Task.sleep(timeout)
            timed_out = true

            for _, running_task in ipairs(running_tasks) do
                running_task:cancel()
            end

            callback(false, Task.timeout)
        end)
    end
end, 3, { async_only = true })

---@class WaitAllResult
---@field ok boolean
---@field result any

--- Run tasks waiting for all the finish successfully or not
---@param tasks (function | parcel.Task)[]
---@param options parcel.task.WaitOptions?
---@return boolean # whether execution succeeded or not (e.g. false if timed out)
---@return WaitAllResult[] # result of execution
function Task.wait_all(tasks, options)
    return wait_all(tasks, options)
end

local first = Task.wrap(function(tasks, callback)
    local done = false
    local running_tasks = {}

    for idx, task in ipairs(tasks) do
        local _task = Task.run(task, function(ok, ...)
            if not done then
                done = true

                -- Cancel other running tasks
                for task_idx, running_task in ipairs(running_tasks) do
                    if task_idx ~= idx then
                        running_task:cancel()
                    end
                end

                callback(...)
            end
        end)

        table.insert(running_tasks, _task)
    end
end, 2)

--- Run a bunch of tasks and return the result of the first one to complete
---@param tasks parcel.Task[]
---@return boolean # whether the task succeeded or not
---@return any # task result
function Task.first(tasks)
    return first(tasks)
end

local wait_scheduler = Task.wrap(vim.schedule, 1)

--- Wait for the scheduler
function Task.wait_scheduler()
    wait_scheduler()
end

--- Create a new task
---@param func function
---@return parcel.Task
function Task.new(func)
    vim.validate({ func = { func, "function" }})

    return setmetatable({
        _id = get_next_task_id(),
        _func = func,
        _coroutine = nil,
        _run_callback = nil,
        _wait_callback = nil,
        _start_time = nil,
        _end_time = nil,
        _failed = false,
        _cancelled = false,
    }, Task)
end

---@private
function Task:check_state()
    if self:started() then
        error("Cannot run task that has already been started")
    end

    if self:failed() then
        error("Cannot run task that has failed")
    end

    if self:done() then
        error("Cannot run task that is already done")
    end

    if self:cancelled() then
        error("Cannot run task that has been cancelled")
    end
end

--- Set the callback to call when the task finishes
---@private
---@param callback parcel.task.Callback?
function Task:set_callback(callback)
    self._run_callback = callback
end

---@return thread?
function Task:coroutine()
    return self._coroutine
end

function Task:start(...)
    self:check_state()
    local step = nil
    self._coroutine = coroutine.create(self._func)
    local thread = self:coroutine()

    local function callback(ok, result)
        self._end_time = vim.loop.hrtime()
        self._failed = not ok
        self._result = result

        pcall(self._run_callback, ok, result)
        pcall(self._wait_callback, ok, result)
    end

    ---@cast thread thread

    -- This function takes a step in an asynchronous function (coroutine),
    -- running until it hits an asynchronous function call wrapped using
    -- async.wrap (such as vim.loop.fs_stat) which will yield back to the
    -- below coroutine.resume.
    --
    -- The asynchronous function's callback will be overriden to instead call
    -- the step function with its results which will then restart the coroutine
    -- via coroutine.resume yielding (pun intended) async/await-style
    -- programming
    step = function(...)
        if self:cancelled() then
            handle_callback(self, callback, "Task was cancelled")
            return
        end

        local results = { coroutine.resume(thread, ...) }
        local status, nargs, err_or_fn = unpack(results)

        if not status then
            handle_callback(self, callback, nil, formatted_error(
                "Task failed: %s\n%s",
                err_or_fn,
                debug.traceback(thread)
            ))
            return
        end

        if coroutine.status(thread) == "dead" then
            handle_callback(self, callback, results)
            return
        end

        if type(err_or_fn) ~= "function" then
            handle_callback(self, callback, nil, formatted_error(
                "Internal task error: expected function, got %s\n%s\n%s",
                type(err_or_fn),
                vim.inspect(results),
                debug.traceback(thread)
            ))
            return
        end

        local args = { select(4, unpack(results)) }

        -- Overwrite the callback to instead call the step function
        args[nargs] = step

        err_or_fn(unpack(args, 1, nargs))
    end

    self._start_time = vim.loop.hrtime()
    step(...)

    return self
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

---@return boolean
function Task:running()
    return self:started() and not self:done()
end

---@private
---@param err any
function Task:set_error(err)
    self._error = err
end

---@return any
function Task:error()
    return self._error
end

function Task:cancel()
    if self:cancelled() then
        error("Attempt to cancel task that was already cancelled")
    end

    self._cancelled = true
end

-- TODO: Check that we are not waiting inside ourselves
local wait = Task.wrap(function(self, timeout, callback)
    if not self:started() then
        error("Cannot wait for task that has not been started")
    end

    if self:done() or self:failed() or self:cancelled() then
        callback()
        return
    end

    self._wait_callback = callback

    if timeout then
        Task.run(function()
            Task.sleep(timeout)

            if self:running() then
                self:cancel()
                callback(false, Task.timeout)
            end
        end)
    end
end, 3, { async_only = true })

--- Wait for a task to finish
---@param timeout number? milliseconds to wait before timing out and cancelling the task
function Task:wait(timeout)
    return wait(self, timeout)
end

--- Return the elapsed time in milliseconds or the total duration of the task
--- if done. Returns -1 if the task has not been started yet.
---@return number
function Task:elapsed_ms()
    if not self:started() then
        return -1
    end

    local end_time = self._end_time or vim.loop.hrtime()

    return (end_time - self._start_time) / 1000000
end

return Task
