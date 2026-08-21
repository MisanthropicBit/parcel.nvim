-- This file provides convenience functions for easier asynchronous programming
-- that avoids callback hell.
--
-- It runs function inside coroutines which suspend when calling an
-- asynchronous function (like vim.uv.fs_stat) and overrides its callback to
-- resume the suspended coroutine, allowing for await-style programming.
--
-- The Task.wrap function transforms a callback-style asynchronous function
-- into a function that instead uses coroutines to start and resume when the
-- original callback is invoked.

---@class parcel.task.WaitOptions
---@field timeout integer? timeout in milliseconds

---@class parcel.task.WaitAllOptions: parcel.task.WaitOptions
---@field concurrency integer? how many tasks can run concurrently at a time

---@class parcel.task.FirstOptions
---@field timeout integer? timeout in milliseconds

---@class parcel.task.WaitAllResult
---@field ok boolean
---@field result any

---@alias parcel.task.Callback fun(ok: boolean, results_or_error: any)

local NANO_TO_MILLISECONDS = 1000000

---@type table<thread, parcel.Task>
local _running_tasks = {}

---@return boolean
local function is_main_coroutine()
    return coroutine.running() == nil
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
---@field private _callbacks function[]
---@field private _start_time number
---@field private _end_time number
---@field private _failed boolean
---@field private _cancelled boolean
---@field private _parent parcel.Task?
---@field private _child_tasks table<number, parcel.Task>
local Task = {}

Task.__index = Task

--- Value returned when a task times out
Task.Timeout = "Timeout"

--- Value returned when a task gets cancelled
Task.Cancelled = "Cancelled"

--- Create a new task but do not run it
---@param func function
---@return parcel.Task
function Task.new(func)
    vim.validate({ func = { func, "function" } })

    return setmetatable({
        _id = get_next_task_id(),
        _func = func,
        _coroutine = nil,
        _callbacks = {},
        _start_time = nil,
        _end_time = nil,
        _failed = false,
        _cancelled = false,
        _parent = nil,
        _child_tasks = {},
    }, Task)
end

---@private
function Task:check_state()
    if self:running() then
        error("Cannot run task that is already running")
    end

    if self:failed() then
        error("Cannot run task that has failed")
    end

    if self:cancelled() then
        error("Cannot run task that has been cancelled")
    end

    if self:completed() then
        error("Cannot run task that has already completed")
    end
end

---@private
---@param ok boolean
---@param result any
function Task:handle_callback(ok, result)
    if ok then
        self._result = unpack(result, 2, table.maxn(result))
    else
        self._failed = not self:cancelled()
        self._result = result
    end

    self._end_time = vim.uv.hrtime()
    _running_tasks[self:coroutine()] = nil

    -- If the task has a parent then remove itself from the parent's table of
    -- child tasks. If the task has child tasks, cancel them since we are now
    -- done
    if self:parent() then
        self:parent():remove_child_task(self)
    elseif vim.tbl_count(self._child_tasks) > 0 then
        self:cancel_child_tasks()
    end

    if #self._callbacks > 0 then
        local errors = {}

        for _, callback in ipairs(self._callbacks) do
            -- We need to call callbacks in a pcall as one might fail so that
            -- the others never gets executed.
            local _ok, err = pcall(callback, ok, self:result())

            if not _ok then
                table.insert(errors, err)
            end
        end

        if #errors > 0 then
            error(table.concat(errors, "\n"))
        end
    else
        if self:failed() then
            -- This is essentially an unhandled promise rejection
            error(("Task failed without callback: %s"):format(tostring(self._result)))
        end
    end
end

--- Start a task
---@return parcel.Task
function Task:start(...)
    self:check_state()
    local step = nil
    self._coroutine = coroutine.create(self._func)
    local thread = self:coroutine()

    self._parent = Task.current()

    if self._parent then
        self._parent:add_child_task(self)
    end

    ---@cast thread thread

    -- This function takes a step in an asynchronous function (coroutine),
    -- running until it hits an asynchronous function call wrapped using
    -- Task.wrap (such as vim.uv.fs_stat) which will yield back to the
    -- below coroutine.resume.
    --
    -- The asynchronous function's callback will be overriden to instead call
    -- the step function with its results which will then restart the coroutine
    -- via coroutine.resume yielding (pun intended) async/await-style
    -- programming
    step = function(...)
        if self:cancelled() then
            self:handle_callback(false, Task.Cancelled)
            return
        end

        local results = { coroutine.resume(thread, ...) }
        local status, nargs, err_or_fn = unpack(results)
        ---@cast status boolean
        ---@cast nargs -boolean, +number | string
        ---@cast err_or_fn -boolean, +string | function

        if not status then
            self:handle_callback(
                false,
                ("Task failed: %s\n%s"):format(
                    nargs, -- This is the error message if the coroutine failed
                    debug.traceback(thread)
                )
            )
            return
        end

        if coroutine.status(thread) == "dead" then
            self:handle_callback(true, results)
            return
        end

        if type(err_or_fn) ~= "function" then
            self:handle_callback(
                false,
                ("Internal task error: expected function, got %s\n%s\n%s"):format(
                    type(err_or_fn),
                    vim.inspect(results),
                    debug.traceback(thread)
                )
            )
            return
        end

        -- Unpack the rest of the results (the arguments)
        local args = { select(4, unpack(results)) }

        -- Overwrite the callback to instead call the step function
        args[nargs] = step

        ---@cast nargs -string
        err_or_fn(unpack(args, 1, nargs))
    end

    _running_tasks[thread] = self
    self._start_time = vim.uv.hrtime()
    step(...)

    return self
end

--- Run a task or create one if the first argument is a function and immediately run it
---@param func_or_task function | parcel.Task
---@param callback parcel.task.Callback?
---@param ... unknown any extra arguments for the initial invocation of the task
---@return parcel.Task
function Task.run(func_or_task, callback, ...)
    local task = func_or_task

    if Task.is_task(func_or_task) then
        ---@cast func_or_task -function
        func_or_task:check_state()
        task = func_or_task
    else
        ---@cast func_or_task -parcel.Task
        task = Task.new(func_or_task)
    end

    ---@cast task parcel.Task
    task:add_callback(callback)

    return task:start(...)
end

--- Run a task or create one if the first argument is a function and
--- immediately run it. If the task fails, log the error and rethrow it
---@param func_or_task function | parcel.Task
---@param ... unknown any extra arguments for the initial invocation of the task
---@return parcel.Task
function Task.run_with_logging(func_or_task, ...)
    return Task.run(func_or_task, function(ok, result)
        if not ok then
            require("parcel.log").error(result)
            error(result)
        end
    end, ...)
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
        if is_main_coroutine() then
            if options and options.async_only then
                error("Cannot call async-only function in non-async context")
            end

            -- Allow calling wrapped functions in non-async contexts
            -- TODO: Return from this as well?
            func(...)
        else
            -- Not in main coroutine, yield back to step function
            local results = { coroutine.yield(argc, func, ...) }

            -- At this point we are still executing the callback from an async
            -- function so await the scheduler so we can do things while not
            -- in a fast event
            -- NOTE: Avoids infinite recursion
            -- if options and options.nope ~= true then
            --     Task.wait_scheduler()
            -- end

            return unpack(results)
        end
    end
end

--- Set the callback to call when the task finishes
---@package
---@param callback parcel.task.Callback?
function Task:add_callback(callback)
    table.insert(self._callbacks, callback)
end

---@param maybe_task unknown
---@return boolean
function Task.is_task(maybe_task)
    return getmetatable(maybe_task) == Task
end

--- Get the currently running task if any
---@return parcel.Task?
function Task.current()
    if is_main_coroutine() then
        return nil
    end

    return _running_tasks[coroutine.running()]
end

---@return integer
function Task:id()
    return self._id
end

---@private
---@return parcel.Task?
function Task:parent()
    return self._parent
end

---@private
---@param task parcel.Task
function Task:add_child_task(task)
    self._child_tasks[task:id()] = task
end

---@private
---@param task parcel.Task
function Task:remove_child_task(task)
    self._child_tasks[task:id()] = nil
end

---@private
function Task:cancel_child_tasks()
    for _, child_task in pairs(self._child_tasks) do
        if not child_task:cancelled() then
            child_task:cancel()
        end
    end
end

---@private
---@return thread?
function Task:coroutine()
    return self._coroutine
end

--- The result regardless of the manner of the task's completion
---@return any
function Task:result()
    return self._result
end

--- If the task failed or not
---@return boolean
function Task:failed()
    return self._failed
end

--- If the task was cancelled or not
---@return boolean
function Task:cancelled()
    return self._cancelled
end

--- If the task was started or not regardless of its completion
---@return boolean
function Task:started()
    return self._start_time ~= nil
end

--- If the task has completed and did not fail or get cancelled
---@return boolean
function Task:completed()
    if self:failed() or self:cancelled() then
        return false
    end

    return self._end_time ~= nil
end

--- If the task is currently running (started but not completed, failed, or cancelled)
---@return boolean
function Task:running()
    if self:completed() or self:failed() or self:cancelled() then
        return false
    end

    return self:started()
end

--- Cancel the task. Fails if already cancelled
function Task:cancel()
    if self:cancelled() then
        error("Attempt to cancel task that was already cancelled")
    end

    self._cancelled = true
    self._result = Task.Cancelled
    self:cancel_child_tasks()
end

-- TODO: We should wait for all child tasks here as well
local wait = Task.wrap(function(self, timeout, callback)
    if Task.current() == self then
        -- TODO: Add test
        error("Cannot wait for task within itself")
    end

    if not self:started() then
        error("Cannot wait for task that has not been started")
    end

    -- If we are already done, failed, or cancelled call callback immediately
    if self:completed() or self:failed() or self:cancelled() then
        callback(self:completed(), self:result())
        return
    end

    self:add_callback(callback)

    if timeout then
        Task.run(function()
            Task.sleep(timeout)

            if self:running() then
                self:cancel()
                callback(false, Task.Timeout)
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

    local end_time = self._end_time or vim.uv.hrtime()

    return (end_time - self._start_time) / NANO_TO_MILLISECONDS
end

-- For wrapped functions we first define a local wrapped function and call it
-- from Task.sleep so we can add proper documentation to the public function

local sleep = Task.wrap(function(ms, callback)
    vim.defer_fn(callback, ms)
end, 2)

---@param ms number the amount of milliseconds to sleep
function Task.sleep(ms)
    sleep(ms)
end

---@async
---@param state { timed_out: boolean, completed: boolean, running_tasks: parcel.Task[] }
local function timeout_task(timeout, num_tasks, state)
    Task.run(function()
        Task.sleep(timeout)

        -- Return if we are already done
        if state.completed == num_tasks then
            return
        end

        state.timed_out = true

        for _, running_task in ipairs(state.running_tasks) do
            running_task:cancel()
        end

        callback(false, Task.Timeout)
    end)
end

--- Runs a task with a callback. If the task has already resolved call the
--- callback immediately otherwise start the task and set the callback to be
--- called
---@param task parcel.Task
---@param callback parcel.task.Callback
---@return boolean
local function run_task_with_callback(task, callback)
    if task:running() then
        task:add_callback(callback)
        return true
    elseif task:completed() then
        callback(true, task:result())
    elseif task:cancelled() or task:failed() then
        callback(false, task:result())
    else
        Task.run(task, callback)
        return true
    end

    return false
end

---@param tasks parcel.Task[]
local function cancel_tasks(tasks)
    for _, task in ipairs(tasks) do
        task:cancel()
    end
end

--- Run a bunch of tasks and wait for them all to complete
---@param tasks parcel.Task[]
---@param options parcel.task.WaitAllOptions?
---@param callback fun(boolean, table)
local wait_all = Task.wrap(function(tasks, options, callback)
    if #tasks == 0 then
        error("Empty task list given to Task.wait_all")
    end

    local all_ok = true
    local completed = 0
    local task_idx = 1
    local results = {} ---@type parcel.task.WaitAllResult[]
    local concurrency = math.min(options and options.concurrency or #tasks, 2 * #vim.uv.cpu_info())
    local timeout = options and options.timeout or nil
    local timed_out = false
    local running_tasks = {}

    ---@type fun(idx: integer): fun(ok: boolean, result: any)
    local task_callback

    ---@param idx integer
    local function run_next_task(idx)
        if task_idx > #tasks then
            return
        end

        vim.print(("Got task %d, task_idx is %d"):format(idx, task_idx))

        if timed_out then
            return
        end

        local task = tasks[idx]

        if run_task_with_callback(task, task_callback(idx)) then
            table.insert(running_tasks, task)
        end
    end

    task_callback = function(idx)
        return function(ok, result)
            if timed_out then
                return
            end

            vim.print(("Task %d finished (ok = %s, result nil? %s)"):format(idx, tostring(ok), tostring(result == nil)))
            completed = completed + 1
            results[idx] = { ok = ok, result = result }

            if not ok then
                all_ok = false
            end

            if completed == #tasks then
                -- Finished all tasks, call callback with the results
                callback(all_ok, results)
            else
                -- There are still tasks to run
                task_idx = task_idx + 1
                run_next_task(task_idx)
            end
        end
    end

    -- Start the timeout first since it will immediately wait whereas user tasks
    -- may not
    if timeout and #tasks > 0 then
        Task.run(function()
            Task.sleep(timeout)

            -- Return if we are already done
            if completed == #tasks then
                return
            end

            timed_out = true
            cancel_tasks(running_tasks)
            callback(false, Task.Timeout)
        end)
    end

    -- Start all tasks if #tasks < concurrency or as many tasks as we have
    -- concurrency if #tasks > concurrency
    local min_num_tasks = math.min(#tasks, concurrency)
    task_idx = min_num_tasks

    for idx = 1, min_num_tasks do
        run_next_task(idx)
    end
end, 3, { async_only = true })

--- Run tasks waiting for all the finish successfully or not
---@param tasks (function | parcel.Task)[]
---@param options parcel.task.WaitAllOptions?
---@return boolean # whether execution succeeded or not (e.g. false if timed out)
---@return parcel.task.WaitAllResult[] # result of execution
function Task.wait_all(tasks, options)
    return wait_all(tasks, options)
end

---@param tasks parcel.Task[]
---@param options parcel.task.FirstOptions?
local first = Task.wrap(function(tasks, options, callback)
    local completed = false
    local timed_out = false
    local timeout = options and options.timeout or nil
    local running_tasks = {}

    -- Start the timeout first since it will immediately wait whereas user tasks
    -- may not
    if timeout and #tasks > 0 then
        Task.run(function()
            Task.sleep(timeout)

            if completed then
                return
            end

            timed_out = true
            cancel_tasks(running_tasks)
            callback(false, Task.Timeout)
        end)
    end

    local function task_callback(idx)
        return function(ok, ...)
            if timed_out or completed then
                return
            end

            completed = true

            -- Cancel other running tasks
            for task_idx, running_task in ipairs(running_tasks) do
                if task_idx ~= idx then
                    running_task:cancel()
                end
            end

            callback(true, ...)
        end
    end

    for idx, task in ipairs(tasks) do
        if run_task_with_callback(task, task_callback(idx)) then
            table.insert(running_tasks, task)
        end
    end
end, 3, { async_only = true })

--- Run a bunch of tasks and return the result of the first one to complete
---@param tasks parcel.Task[]
---@param options parcel.task.FirstOptions?
---@return boolean # whether the task succeeded or not
---@return any # task result
function Task.first(tasks, options)
    return first(tasks, options)
end

local wait_scheduler = Task.wrap(vim.schedule, 1)

--- Wait for the scheduler
function Task.wait_scheduler()
    wait_scheduler()
end

return Task
