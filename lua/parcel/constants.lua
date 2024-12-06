local constants = {}

local Path = require("parcel.path")

local lockfile = "parcel.lock.json"

local values = {
    lockfile = lockfile,
    lockpath = Path.join(vim.fn.stdpath("data"), lockfile),
    state_file = "parcel.state.json",
    default_single_task_timeout = 3 * 1000,
    default_multi_task_timeout = 10 * 1000,
}

return setmetatable({}, {
    __index = values,
    __new_index = function(_, key)
        error(("Cannot modify constants (key: '%s')"):format(key))
    end
})
