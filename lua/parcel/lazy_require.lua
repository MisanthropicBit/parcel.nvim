return function(module)
    vim.validate({ module = { module, "string" }})

    return setmetatable({}, {
        __index = function(_, key)
            return require(module)[key]
        end,
    })
end
