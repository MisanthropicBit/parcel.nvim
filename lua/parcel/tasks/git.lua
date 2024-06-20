local git = {}

local log = require("parcel.log")
local process = require("parcel.process")
local Task = require("parcel.tasks")

---@class parcel.GitCloneOptions
---@field dir string
---@field branch string?
---@field commit string?
---@field tag string?

---@class parcel.GitCheckoutOptions
---@field dir string
---@field branch string?
---@field commit string?
---@field tag string?

---@param url string
---@param options parcel.GitCloneOptions?
---@param callback fun(ok: boolean, result: parcel.ProcessResult)
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

---@param dir string
---@param options parcel.GitCheckoutOptions
---@param callback fun(ok: boolean, result: parcel.ProcessResult)
git.checkout = Task.wrap(function(dir, options, callback)
    local args = { "checkout" }
    local _options = options or {}

    if _options.branch then
        table.insert(args, _options.branch)
    elseif _options.commit then
        table.insert(args, _options.commit)
    elseif _options.tag then
        table.insert(args, _options.tag)
    else
        return false, "No arguments given to git checkout"
    end

    -- TODO: Fix logging these types of arguments
    -- log.debug("tasks.git.clone", { args = args })

    process.spawn("git", {
        cwd = dir,
        args = args,
        on_exit = function(result, code, signal)
            result.code = code
            result.signal = signal
            callback(code == 0, result)
        end,
    })
end, 3)

return git
