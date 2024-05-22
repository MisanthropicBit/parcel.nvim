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

local async = {}

---@alias parcel.async.Callback fun(ok: boolean, results_or_error: any)

---@class parcel.async.WaitOptions
---@field concurrency integer?
---@field timeout integer?

---@param msg string
---@param ... any
local function formatted_error(msg, ...)
    error(msg:format(...))
end

--- Handle the callback from an async function
---@param callback parcel.async.Callback?
---@param results any
---@param error any
local function handle_callback(callback, results, error)
    if callback ~= nil then
        if error ~= nil then
            callback(true, { unpack(results, 2, table.maxn(results)) })
        else
            callback(false, error)
        end
    end
end

--- Run a function asynchronously
---@param func function | parcel.Task
---@param callback parcel.async.Callback?
---@param ... unknown
---@return parcel.Task
function async.run(func, callback, ...)
    local step = nil
    local task = func

    if type(func) == "function" then
        task = Task.new(func)
    end

    local thread = task:coroutine()

    ---@cast task parcel.Task
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
        if task:cancelled() then
            handle_callback(callback, "Task was cancelled")
            return
        end

        local results = { coroutine.resume(thread, ...) }
        local status, err_or_fn, nargs = unpack(results)

        if not status then
            handle_callback(callback, nil, formatted_error(
                "Coroutine failed with this message: %s\n%s",
                err_or_fn,
                debug.traceback(thread)
            ))
            return
        end

        if coroutine.status(thread) == "dead" then
            handle_callback(callback, results)
            return
        end

        if type(err_or_fn) ~= "function" then
            handle_callback(callback, nil, formatted_error(
                "Internal async error: expected function, got %s\n%s\n%s",
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

    step(...)

    return task
end

-- Wraps a callback-style asynchronous function returning a function which
-- instead uses coroutines to start and resuming when the original callback is
-- invoked
function async.wrap(func, argc)
    return function(...)
        local thread, is_main = coroutine.running()

        if not is_main then
            -- Not in main coroutine, yield back to step function
            return coroutine.yield(func, argc, ...)
        else
            -- Allow calling wrapped functions in non-async contexts
            func(...)
        end
    end
end

--- Run a bunch of tasks and wait for them all to complete
async.wait_all = async.wrap(function(tasks, options, callback)
    -- TODO: Add concurrency limit
    local done = 0
    local results = {}
    local concurrency = options and options.concurrency or #tasks

    for task_idx = 1, concurrency, 1 do
        Task.run(tasks[task_idx], function(success, result)
            done = done + 1
            results[task_idx] = { success = success, result = result }

            -- Finished all tasks, call callback with the results
            if done == #tasks then
                callback(results)
            end
        end)
    end
end, 3)

--- Run a bunch of tasks and returns the result of the first one to complete
---@param tasks parcel.Task[]
---@param callback parcel.async.Callback
async.first = async.wrap(function(tasks, callback)
    local done = false
    local running_tasks = {}

    for idx, task in ipairs(tasks) do
        local _task = Task.run(task, function(success, ...)
            if not done then
                done = true
                callback(...)
            end
        end)

        table.insert(running_tasks, _task)
    end
end, 2)

-- Runs a bunch of tasks in sequence one after another
async.sequence = async.wrap(function(tasks, step)
end, 2)

async.sleep = async.wrap(function(timespan, callback)
    vim.defer_fn(callback, timespan)
end, 2)

async.timeout = async.wrap(function(task, step)
end, 2)

return async
