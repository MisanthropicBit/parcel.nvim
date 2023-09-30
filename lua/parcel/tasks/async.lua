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

local function formatted_error(msg, ...)
    error(msg:format(...))
end

local function handle_callback(callback, results, error)
    if callback ~= nil then
        if error ~= nil then
            callback(true, { unpack(results, 2, table.maxn(results)) })
        else
            callback(false, error)
        end
    end
end

function async.run(func, callback, ...)
    local thread = coroutine.create(func)
    local step = nil

    -- This function takes a step in an asynchronous function (coroutine in this
    -- case), running until it hits an asynchronous, async.wrapped call
    -- (such as vim.loop.fs_stat) which will yield back to the below
    -- coroutine.resume.
    --
    -- The asynchronous function's callback will be overriden to instead call
    -- the step function with its results which will then restart the coroutine
    -- via coroutine.resume yielding (pun intended) async/await-style programming
    step = function(...)
        local results = { coroutine.resume(thread, ...) }
        local status, err_or_fn, nargs = unpack(results)

        if not status then
            handle_callback(callback, nil, formatted_error(
                "The coroutine failed with this message: %s\n%s",
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
        args[nargs] = step

        err_or_fn(unpack(args, 1, nargs))
    end

    step(...)
end

-- Wraps a callback-style asynchronous function returning a function which
-- instead uses coroutines to start and resuming when the original callback is
-- invoked
function async.wrap(func, argc)
    return function(...)
        if not coroutine.running() then
            return coroutine.yield(func, argc, ...)
        else
            -- Allow calling wrapped functions in non-async contexts
            func(...)
        end
    end
end

-- Run a bunch of tasks and wait for them all to complete
async.wait_all = async.wrap(function(tasks, callback)
    local done = 0
    local results = {}

    for i, task in ipairs(tasks) do
        vim.print(task)
        task:start(function(success, result)
            done = done + 1
            results[i] = { succeeded = success, result = result }

            if success then
                if done == #tasks then
                    callback(results)
                end
            else
                for _, _task in ipairs(tasks) do
                    _task:cancel()
                end

                callback(results)
            end
        end)
    end
end, 2)

-- Runs a bunch of tasks and returns the result of the first one to complete
async.first = async.wrap(function(tasks, step)
end, 2)

-- Runs a bunch of tasks in sequence one after another
async.sequence = async.wrap(function(tasks, step)
end, 2)

async.sleep = async.wrap(function(task, step)
end, 2)

async.timeout = async.wrap(function(task, step)
end, 2)

return async
