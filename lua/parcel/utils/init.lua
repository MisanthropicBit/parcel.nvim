local utils = {}

local lazy_require = require("parcel.utils.lazy_require")

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
        if type(key) == "string" then
            private["_" .. key] = value
        end
    end

    return private
end

utils.git = lazy_require.lazy_require("parcel.utils.git")
utils.str = lazy_require.lazy_require("parcel.utils.str")
utils.version = lazy_require.lazy_require("parcel.utils.version")

return utils
