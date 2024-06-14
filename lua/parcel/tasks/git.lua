local git = {}

local log = require("parcel.log")
local process = require("parcel.process")
local Task = require("parcel.tasks")

---@param url string
git.clone = Task.wrap(function(url, options, callback)
    local args = {
        "clone",
        url,
        "--depth",
        "1",
    }
    local _options = options or {}

    if _options.branch then
        vim.list_extend(args, { "--branch", _options.branch })
    end

    table.insert(args, _options.dir)

    -- TODO: Fix logging these types of arguments
    -- log.debug("tasks.git.clone", { args = args })

    process.spawn("git", {
        args = args,
        on_exit = function(result, code, signal)
            result.code = code
            result.signal = signal
            callback(code == 0, result)
        end,
    })
end, 3)

return git
