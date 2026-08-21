local fs = {}

---@alias parcels.fs.FileMatcher fun(name: string, path: string): boolean

-- TODO: Clear cache when parcels are deleted/updated
local find_file_cache = {}

---@param cache_key string
---@param path string
---@param matcher string[] | parcels.fs.FileMatcher
---@param options vim.fs.find.Opts?
---@return string[]
local function find_and_cache_file(cache_key, path, matcher, options)
    if find_file_cache[path] and find_file_cache[path][cache_key] then
        return find_file_cache[path][cache_key]
    end

    local paths = fs.find_by_name(path, matcher, options)

    if #paths > 0 then
        if not find_file_cache[path] then
            find_file_cache[path] = { [cache_key] = paths }
        end

        return paths
    end

    return {}
end

function fs.open(path) end

--- Find files that match a set of filenames at a path
---@param path string
---@param filenames string[] | parcels.fs.FileMatcher
---@param options vim.fs.find.Opts?
---@return string[]
function fs.find_by_name(path, filenames, options)
    ---@type parcels.fs.FileMatcher
    local matcher

    if type(filenames) == "table" then
        matcher = function(name, _path)
            return vim.list_contains(filenames, name)
        end
    else
        matcher = filenames
    end

    local matches = vim.fs.find(
        matcher,
        vim.tbl_extend("force", {
            limit = 1,
            type = "file",
            path = path,
        }, options or {})
    )

    return vim.tbl_map(vim.fs.abspath, matches)
end

---@param cache_key string
function fs.clear_find_cache_entry(cache_key)
    find_file_cache[cache_key] = nil
end

function fs.clear_find_cache()
    find_file_cache = {}
end

--- Try to find the documentation file at a path
---@param path string
---@return string[]
function fs.find_docs(path)
    return find_and_cache_file("docs", path, { "README.md", "README.rst" })
end

--- Try to find the help file at a path
---@param path string
---@return string[]
function fs.find_help_files(path)
    local pattern = vim.glob.to_lpeg("*.txt")

    return find_and_cache_file("help", path, function(name, _path)
        return name:match(".*%.txt$") and vim.endswith(_path, "doc")
    end, { limit = 2 })
end

--- Try to find the license file at a path
---@param path string
---@return string[]
function fs.find_licenses(path)
    return find_and_cache_file("license", path, function(name)
        return vim.startswith(name:lower(), "license")
    end)

    -- NOTE: Support license type?
    -- local license_type = vim.trim(vim.fn.readfile(license_paths, nil, 1)[1])
end

return fs
