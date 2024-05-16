local log = {}

local Path = require("parcel.path")

local separator = "|"
local log_level = vim.log.levels.WARN -- vim.fn.getenv("PARCEL_LOG_LEVEL") or vim.log.levels.WARN
local date_format = "%FT%H:%M:%SZ%z"

---@class parcel.Logger
local Logger = {}

---@param filename string
---@param options? { level?: 0 | 1 | 2 | 3 | 4 | 5 }
---@return parcel.Logger
function Logger:new(filename, options)
    local _options = options or {}
    local path = Path:new(vim.fn.stdpath("log"), filename):add_extension("log")

    local logger = setmetatable({}, { __index = self })
    local logfile = path:absolute()

    -- TODO: Handle more gracefully
    local handle = assert(io.open(logfile, "a+"), "Failed to open log file")

    logger._path = path
    logger._level = _options.level or log_level

    for level_name, level in pairs(vim.log.levels) do
        local _name = level_name:lower()

        if _name == "off" then
            goto continue
        end

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
                    separator,
                    os.date(date_format),
                    separator,
                    fileinfo,
                    separator,
                }, " "),
            }

            local format = select(2, ...)
            table.insert(parts, format:format(select(3, ...)))

            -- for i = 1, argc do
            --     local arg = select(i, ...)

            --     if arg == nil then
            --         table.insert(parts, "<nil>")
            --     elseif type(arg) == "string" then
            --         table.insert(parts, arg)
            --     elseif type(arg) == "table" and arg.__tostring then
            --         table.insert(parts, arg.__tostring(arg))
            --     else
            --         table.insert(parts, vim.inspect(arg))
            --     end
            -- end

            -- TODO: When should this be closed?
            handle:write(table.concat(parts, " "), Path.newline)
            handle:flush()
        end

        ::continue::
    end

    return logger
end

local default_logger = Logger:new("parcel")

for level, _ in pairs(vim.log.levels) do
    local _level = level:lower()

    if _level ~= "off" then
        log[_level] = function(...)
            default_logger[_level](default_logger, ...)
        end
    end
end

return log
