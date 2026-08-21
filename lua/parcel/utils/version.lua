local _version = {}

---@param version string | vim.Version | vim.VersionRange
---@return string
function _version.format(version)
    if type(version) == "string" then
        return version
    elseif version.major ~= nil then
        ---@cast version vim.Version
        return tostring(version)
    else
        ---@cast version vim.VersionRange
        return ("%s - %s"):format(version.from, version.to)
    end
end

return _version
