local git = {}

local log = require("parcel.log")
local process = require("parcel.process")
local Task = require("parcel.tasks.task")

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

---@class parcel.GitFetchOptions
---@field args string[]?

---@class parcel.GitPullOptions

---@param subcommand string
---@param args string[]
---@param callback parcel.ProcessOnExitHandler
local function execute_git(subcommand, args, callback)
    table.insert(args, 1, subcommand)

    -- TODO: Fix logging these types of arguments
    -- log.debug("tasks.git.clone", { args = args })

    process.spawn(
        "git",
        vim.tbl_extend("force", args, {
            on_exit = function(result, code, signal)
                result.code = code
                result.signal = signal
                callback(code == 0, result)
            end,
        })
    )
end

git.default_branch = Task.wrap(function(dir, callback)
    execute_git("rev-parse", { "--abbrev-ref", "origin/HEAD" }, callback)
end, 2)

git.sha = Task.wrap(function(dir, object, callback)
    execute_git("rev-list", { "-1", "--abbrev-commit", object }, callback)
end, 3)

---@param url string
---@param options parcel.GitCloneOptions?
---@param callback fun(ok: boolean, result: parcel.ProcessResult)
git.clone = Task.wrap(function(url, options, callback)
    local args = {
        url,
        "--depth",
        "1",
    }
    local _options = options or {}

    if _options.branch then
        vim.list_extend(args, { "--branch", _options.branch })
    end

    table.insert(args, _options.dir)

    execute_git("clone", args, callback)
end, 3)

---@param dir string
---@param options parcel.GitCheckoutOptions
---@param callback fun(ok: boolean, result: parcel.ProcessResult)
git.checkout = Task.wrap(function(dir, options, callback)
    local args = {}
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

    execute_git("checkout", args, callback)
end, 3)

---@param dir string
---@param options parcel.GitFetchOptions
---@param callback fun(ok: boolean, result: parcel.ProcessResult)
git.fetch = Task.wrap(function(dir, options, callback)
    execute_git("fetch", options.args or {}, callback)
end, 3)

---@param dir string
---@param options parcel.GitPullOptions
---@param callback fun(ok: boolean, result: parcel.ProcessResult)
git.pull = Task.wrap(function(dir, options, callback)
    local args = {}
    local _options = options or {}

    execute_git("pull", args, callback)
end, 3)

return git
