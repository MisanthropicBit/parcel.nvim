local utils = {}

--- Get the path of the currently executing script
---@return string
function utils.get_script_path()
    local str = debug.getinfo(3, "S").source:sub(2)

    return str
end

-- Returns a copy of a table where field names have been prefixed by underscore
---@param tbl table<string, unknown>
---@return table<string, unknown>
function utils.privatise_options(tbl)
    local private = {}

    for key, value in pairs(tbl) do
        private["_" .. key] = value
    end

    return private
end

utils.git = require("parcel.utils.git")
utils.str = require("parcel.utils.str")

return utils
