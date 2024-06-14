local utils = {}

local Path = require("parcel.path")

--- Get the path of the currently executing script
---@return string
function utils.get_script_path()
    vim.print(vim.inspect(debug.getinfo(3, "S")))
    local str = debug.getinfo(3, "S").source:sub(2)

    return str

    -- return str:match(Path.join("(.*", ")"))
end

---@param name string
---@return string
function utils.clean_parcel_name(name)
    local result = name:lower():gsub("^n?vim%-", "", 1):gsub("%.n?vim$", "", 1)

    return result
end

return utils
