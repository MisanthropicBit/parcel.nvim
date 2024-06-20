local constants = {}

local Path = require("parcel.path")

local lockfile_path = Path.join(vim.fn.stdpath("data"), "parcel.lock.json")

function constants.lockfile()
    return lockfile_path
end

function constants.state_file()
    return "parcel.state.json"
end

return constants
