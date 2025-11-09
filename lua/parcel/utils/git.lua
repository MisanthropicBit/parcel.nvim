local git = {}

---@param value unknown
function git.is_sha(value)
    return type(value) == "string" and vim.fn.match(value, [[^[a-zA-Z0-9]\{,40}$]])
end

return git
