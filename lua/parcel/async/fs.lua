local compat = require("parcel.compat")
local Task = require("parcel.tasks")

---@type table<string, integer>
local async_fs = {
    access = 3,
    close = 2,
    closedir = 2,
    fstat = 2,
    open = 4,
    opendir = 2,
    read = 4,
    readdir = 2,
    stat = 2,
}

local cache = {
    ---@param name string
    ---@param flags string?
    ---@param prot integer?
    --–@return integer
    mkdirs = function(name, flags, prot)
        -- Not really an async function but added for convenience so we don't
        -- have to remember to wait for the scheduler
        if vim.in_fast_event() then
            Task.wait_scheduler()
        end

        vim.fn.mkdir(name, flags, prot)
    end,
}

return setmetatable({}, {
    __index = function(_, key)
        local func = cache[key]

        if func then
            return func
        end

        local argc = async_fs[key]

        if not argc then
            error(("Failed to access unknown async fs function with name '%s'"):format(key))
        end

        func = Task.wrap(compat.loop["fs_" .. key], argc)
        cache[key] = func

        return func
    end
})
