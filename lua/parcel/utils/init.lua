local utils = {}

local lazy_require = require("parcel.utils.lazy_require")
local Path = require("parcel.path")

-- TODO: Clear cache when parcels are deleted/updated
local find_file_cache = {}

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

--- Try to find the documentation file at a path
---@param path string
---@return string?
function utils.find_docs(path)
    -- TODO: Move elsewhere
    if find_file_cache[path] and find_file_cache[path].docs then
        return find_file_cache[path].docs
    end

    local readme_paths = require("parcel.fs").find_by_name(path, { "README.md", "README.rst" })

    if #readme_paths > 0 then
        local readme_path = vim.fs.basename(readme_paths[1])

        if not find_file_cache[path] then
            find_file_cache[path] = { docs = readme_path }
        end

        return readme_path
    end
end

--- Try to find the license file at a path
---@param path string
---@return { name: string, type: string }?
function utils.find_license(path)
    -- TODO: Move elsewhere
    if find_file_cache[path] and find_file_cache[path].license then
        return find_file_cache[path].license
    end

    local license_paths = require("parcel.fs").find_by_name(path, function(name)
        return vim.startswith(name, "LICENSE")
    end)

    if #license_paths > 0 then
        local license_path = license_paths[1]
        local license_type = vim.trim(vim.fn.readfile(license_path, nil, 1)[1])
        local license_name = vim.fs.basename(license_path)
        -- local license = vim.fs.basename(license_path) .. " (" .. license_type .. ")"

        if not find_file_cache[path] then
            find_file_cache[path] = { license = { name = license_name, type = license_type } }
        end

        return { name = license_name, type = license_type }
    end
end

utils.color = lazy_require.lazy_require("parcel.utils.color")
utils.git = lazy_require.lazy_require("parcel.utils.git")
utils.str = lazy_require.lazy_require("parcel.utils.str")
utils.version = lazy_require.lazy_require("parcel.utils.version")

return utils
