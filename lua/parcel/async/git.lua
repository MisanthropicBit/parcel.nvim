---@class git
---@field default_branch fun(dir: string): boolean, parcel.ProcessResult Get the default git branch name
---@field sha            fun(dir: string, object: string): boolean, parcel.ProcessResult Get the sha of an object
---@field fetch          fun(dir: string, options: parcel.GitFetchOptions): boolean, parcel.ProcessResult Do a git fetch
local git = {}

local log = require("parcel.log")
local process = require("parcel.process")
local Task = require("parcel.tasks.task")

---@class parcel.GitFetchOptions
---@field args string[]?

---@param subcommand string
---@param args string[]
---@param path string
---@param callback parcel.ProcessOnExitHandler
local function execute_git(subcommand, args, path, callback)
    table.insert(args, 1, subcommand)

    log.error("Running git command with arguments", args, "at path", path)

    process.spawn(
        "git",
        {
            args = args,
            cwd = path,
            on_exit = function(result, code, signal)
                result.code = code
                result.signal = signal

                callback(code == 0, result)
            end,
        }
    )
end

git.default_branch = Task.wrap(function(dir, callback)
    execute_git("rev-parse", { "--abbrev-ref", "origin/HEAD" }, dir, callback)
end, 2)

git.sha = Task.wrap(function(dir, object, callback)
    execute_git("rev-list", { "-1", "--abbrev-commit", object }, dir, callback)
end, 3)

git.fetch = Task.wrap(function(dir, options, callback)
    execute_git("fetch", options.args or {}, dir, callback)
end, 3)

return git
