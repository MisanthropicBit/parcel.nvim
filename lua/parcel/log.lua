local log = {}

local Path = require("parcel.path")

---@class parcel.Logger

local default_log_level = vim.log.levels.INFO
local date_format = "%FT%H:%M:%SZ%z"

local env = vim.fn.getenv("PARCEL_LOG_LEVEL")
env = env == vim.NIL or true

local Logger = {}

function Logger:new(name, options)
    local _options = options or {}
    local path = Path:new(vim.fn.stdpath("log"), "parcel")
    local abspath = path:absolute()

    local result = vim.fn.mkdir(abspath, "p")
    assert(result == 1, "Failed to create directory for logging")

    self.__index = self
    local logger = setmetatable({}, self)
    local logfile = path / (name .. ".log")
    local handle = assert(io.open(logfile:absolute(), "a+"), "Failed to open log file")

    logger._path = path
    logger._level = _options.level or vim.log.levels.WARN

    for level_name, level in pairs(vim.log.levels) do
        local _name = level_name:lower()

        if _name ~= "off" then
            logger[_name] = function(...)
                if level < logger._level then
                    return false
                end

                local argc = select("#", ...)

                if argc == 0 then
                    return true
                end

                local info = debug.getinfo(2, "Sl")
                local fileinfo = ("%s:%s"):format(info.short_src, info.currentline)
                local parts = {
                    table.concat({
                        level_name,
                        "|",
                        os.date(date_format),
                        "|",
                        fileinfo,
                        "|",
                    }, " "),
                }

                for i = 1, argc do
                    local arg = select(i, ...)

                    if arg == nil then
                        table.insert(parts, "<nil>")
                    elseif type(arg) == "string" then
                        table.insert(parts, arg)
                    elseif type(arg) == "table" and arg.__tostring then
                        table.insert(parts, arg.__tostring(arg))
                    else
                        table.insert(parts, vim.inspect(arg))
                    end
                end

                -- TODO: When should this be closed?
                handle:write(table.concat(parts, " "), Path.newline)
                handle:flush()
            end
        end
    end

    return logger
end

local default_logger = Logger:new("default")

for level, _ in pairs(vim.log.levels) do
    local _level = level:lower()

    if _level ~= "off" then
        log[_level] = function(...)
            default_logger[_level](default_logger, ...)
        end
    end
end

return log
