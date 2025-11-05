local lazy_require = {}

---@param module string
function lazy_require.lazy_require(module)
    vim.validate("module", module, "string")

    return setmetatable({}, {
        __index = function(_, key)
            return require(module)[key]
        end,
    })
end

---@param prefix string
function lazy_require.prefixed_lazy_require(prefix)
    vim.validate("prefix", prefix, "string")

    return function(module)
        return lazy_require.lazy_require(prefix .. "." .. module)
    end
end

return lazy_require
