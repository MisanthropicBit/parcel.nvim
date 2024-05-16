local git = {}

local async = require("parcel.tasks.async")
local log = require("parcel.log")
local process = require("parcel.process")

---@param url string
git.clone = async.wrap(function(url, options, callback)
    local args = {
        "clone",
        url,
        "--progress",
        "--depth",
        "1",
    }
    local _options = options or {}

    if _options.branch then
        vim.list_extend(args, { "--branch", _options.branch })
    end

    table.insert(args, _options.dir)

    -- TODO: Fix logging these types of arguments
    log.debug("tasks.git.clone", { args = args })

    return process.spawn("git", {
        args = args,
        on_exit = function(success, result)
            local on_exit = _options.on_exit
            vim.print(success)
            vim.print(vim.inspect(result))

            if on_exit and type(on_exit) == "function" then
                on_exit(success, result)
            end

            if callback then
                callback(success, result)
            end
        end
    })
end, 3)

return git
