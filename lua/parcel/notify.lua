local notify = {}

local log = require("parcel.log")

local supported_levels = {
    debug = vim.log.levels.DEBUG,
    info = vim.log.levels.INFO,
    warn = vim.log.levels.WARN,
    error = vim.log.levels.ERROR,
}

---@param message string
---@param level integer
---@param ... any
local function _notify(message, level, ...)
    local args = { ... }

    -- Notification may be overridden by the user and call vimscript functions or
    -- functions that are not safe to call in async code
    if vim.in_fast_event() then
        vim.schedule(function()
            vim.notify(message:format(unpack(args)), level)
        end)
    else
        vim.notify(message:format(unpack(args)), level)
    end
end

notify.log = {}

for name, level in pairs(supported_levels) do
    ---@param message string
    ---@param ... any
    local notify_func = function(message, ...)
        _notify(message, level, ...)
    end

    notify[name] = notify_func

    notify.log[name] = function(message, ...)
        notify_func(message, ...)
        log[name](message, ...)
    end
end

---@param task parcel.Task
---@param task_name string?
function notify.log.task_result(task, task_name)
    local elapsed_ms = task:elapsed_ms()
    local _task_name = task_name

    if not _task_name then
        _task_name = vim.fn.fnamemodify(debug.getinfo(2, "S").source:sub(2), ":t:r")
    end

    if task:failed() then
        notify.log.error(
            "Task '%s' failed (%d milliseconds): %s",
            _task_name,
            elapsed_ms,
            task:error()
        )
    elseif task:cancelled() then
        notify.log.debug(
            "Task '%s' got cancelled (%d milliseconds): %s",
            _task_name,
            elapsed_ms
        )
    else
        log.debug("Task '%s' completed (%d milliseconds)", _task_name, elapsed_ms)
    end
end

return notify
