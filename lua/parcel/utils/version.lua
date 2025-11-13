local _version = {}

---@param version string | vim.Version | vim.VersionRange
---@return string
function _version.format(version)
    if type(version) == "string" then
        return version
    elseif version.major ~= nil then

    end
end

return _version
