local fs = {}

---@alias parcels.fs.FileMatcher fun(name: string, path: string): boolean

--- Find files that match a set of filenames at a path
---@param path string
---@param filenames string[] | parcels.fs.FileMatcher
---@return string[]
function fs.find_by_name(path, filenames)
    ---@type parcels.fs.FileMatcher
    local matcher

    if type(filenames) == "table" then
        matcher = function(name, _path)
            return vim.list_contains(filenames, name)
        end
    else
        matcher = filenames
    end

    local matches = vim.fs.find(matcher, {
        limit = 1,
        type = "file",
        path = path
    })

    return vim.tbl_map(vim.fs.abspath, matches)
end

return fs
