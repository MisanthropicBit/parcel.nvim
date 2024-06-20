local utils = {}

local Path = require("parcel.path")

--- Get the path of the currently executing script
---@return string
function utils.get_script_path()
    local str = debug.getinfo(3, "S").source:sub(2)

    return str

    -- return str:match(Path.join("(.*", ")"))
end

---@param name string
---@return string
function utils.clean_parcel_name(name)
    local result = name:lower()

    result = vim.fn.substitute(result, [[\v^\s*n?vim-]], "", "")
    result = vim.fn.substitute(result, [[\v\.n?vim\s*$]], "", "")

    return vim.fn.trim(result)
end

utils.str = require("parcel.utils.str")

return utils
