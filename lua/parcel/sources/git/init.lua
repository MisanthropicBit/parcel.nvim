---@type parcel.Source
---@diagnostic disable-next-line: missing-fields
local git_source = {}

function git_source.name()
    return "git"
end

---@param parcel parcel.Parcel
---@param value unknown
---@param open_type string
---@return boolean
function git_source.handle_open(parcel, value, open_type)
    if open_type == "source" then
        vim.ui.open(value)
        return true
    elseif open_type == "version" or open_type == "revision" then
        vim.ui.open(("%s/tree/%s"):format(parcel:source_url(), value))
        return true
    end

    return false
end

function git_source.write_section(parcel, section)
    return {
        { "Version", { tostring(parcel:version() or "-") } },
        { "Revision", { parcel:revision() } }
    }
end

function git_source.has_update(parcel)
    -- TODO: Move update_checker code here
end

return git_source
