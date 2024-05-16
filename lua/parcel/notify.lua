local notify = {}

local log = require("parcel.log")

local supported_levels = {
    debug = vim.log.levels.DEBUG,
    error = vim.log.levels.ERROR,
    info = vim.log.levels.INFO,
    warn = vim.log.levels.WARN,
}

---@param message string
---@param level integer
---@param ... any
local function _notify(message, level, ...)
    vim.notify(message:format(...), level)
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

return notify
