local async_fs = {}

local compat = require("parcel.compat")
local Path = require("parcel.path")
local Task = require("parcel.tasks")

---@class parcel.IterDirOptions
---@field recursive boolean?
---@field depth integer?
---@field num_entries integer?
---@field filter (fun(entry: uv.aliases.fs_readdir_entries): boolean)?

local default_iter_dir_options = {
    recursive = false,
    depth = 1,
    num_entries = 10,
    filter = nil
}

---@type table<string, integer>
local async_fs_argc = {
    access = 3,
    close = 2,
    closedir = 2,
    fstat = 2,
    lstat = 2,
    open = 4,
    opendir = 2, -- TODO: Support 'entries' argument
    read = 4,
    readdir = 2,
    rmdir = 2,
    stat = 2,
}

---@type table<string, function>
local cache = {}

---@param name string
---@param flags string?
---@param prot integer?
--–@return integer
local function mkdirs(name, flags, prot)
    -- Not really an async function but added for convenience so we don't
    -- have to remember to wait for the scheduler
    if vim.in_fast_event() then
        Task.wait_scheduler()
    end

    vim.fn.mkdir(name, flags, prot)
end

---@async
---@param path string
---@reutrn boolean, unknown?
local function dir_exists(path)
    local err, stat = async_fs.stat(vim.fs.normalize(path))

    if err ~= nil then
        return false, err
    end

    -- TODO: Check mode as well?
    return stat.type == "directory", "Path is not a directory"
end

---@async
---@param path string | parcel.Path
---@param options parcel.IterDirOptions?
local function iter_dir(path, options)
    -- TODO: Validate options
    -- vim.validate({
    --     recursive = { options.recursive, "boolean"  }
    -- })

    ---@type parcel.IterDirOptions
    local _options = vim.tbl_extend("keep", options or {}, default_iter_dir_options)
    local depth = 1
    local curpath = path

    if type(path) ~= "string" then
        curpath = path:absolute()
    end

    ---@cast curpath string
    curpath = vim.fs.normalize(curpath)

    ---@type uv_fs_t, any?, any?
    local dir_stream, open_err, read_err
    local idx ---@type integer?
    local dir_stack = { curpath } ---@type string[]

    ---@type uv.aliases.fs_readdir_entries[]
    local directories = {
        { name = curpath, type = "directory" },
    }

    ---@type uv.aliases.fs_readdir_entries[]
    local entries = {}

    return function()
        ---@type uv.aliases.fs_readdir_entries
        local entry
        idx, entry = next(entries, idx)

        if idx then
            if entry.type == "directory" and _options.recursive == true then
                if depth < _options.depth then
                    table.insert(directories, entry)
                end
            end

            if _options.filter then
                if _options.filter(entry) then
                    return entry
                end
            else
                return entry
            end
        else
            idx = nil
            entries, read_err = async_fs.readdir(dir_stream)

            if read_err then
                error(("Failed to read directory '%s': %s"):format(curpath, read_err))
            elseif not entries then
                -- No more entries in this directory
                async.fs.closedir(dir_stream)

                if depth <= _options.depth then
                    local next_directory = table.remove(directories, 1)

                    if not next_directory then
                        return nil
                    end

                    curpath = Path.join(unpack(dir_stack), next_directory.name)
                    -- TODO: Support num_entries
                    open_err, dir_stream = async_fs.opendir(curpath)

                    if open_err then
                        error(("Failed to open directory '%s': %s"):format(curpath, open_err))
                    end

                    read_err, entries = async_fs.readdir(dir_stream)

                    if read_err then
                        error(("Failed to read directory '%s': %s"):format(curpath, read_err))
                    end

                    depth = depth + 1
                end
            end
        end
    end
end

-- iter_modules = function(name)
-- end

cache["mkdirs"] = mkdirs
cache["dir_exists"] = dir_exists
cache["iter_dir"] = iter_dir

return setmetatable(async_fs, {
    __index = function(_, key)
        local func = cache[key]

        if func then
            return func
        end

        local argc = async_fs_argc[key]

        if not argc then
            error(("Failed to access unknown async fs function with name '%s'"):format(key))
        end

        func = Task.wrap(compat.loop["fs_" .. key], argc)
        cache[key] = func

        return func
    end
})
