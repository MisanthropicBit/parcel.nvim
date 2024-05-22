local async = require("parcel.async")

---@type table<string, integer>
local async_fs = {
    access = 3,
    stat = 2,
}

local cache = {}

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

        func = async.wrap(vim.loop["fs_" .. key], argc)
        cache[key] = func

        return func
    end
})
