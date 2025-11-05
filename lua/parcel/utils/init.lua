local utils = {}

--- Get the path of the currently executing script
---@return string
function utils.get_script_path()
    local str = debug.getinfo(3, "S").source:sub(2)

    return str
end

utils.git = require("parcel.utils.git")
utils.str = require("parcel.utils.str")

return utils
