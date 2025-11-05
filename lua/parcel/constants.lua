local values = {
    namespace = vim.api.nvim_create_namespace("parcel"),
    lockfile = vim.env.XDG_CONFIG_HOME .. "/nvim/nvim-pack-lock.json.",
    version = "0.1.0",
}

return setmetatable({}, {
    __index = values,
    __new_index = function(_, key)
        error(("Cannot modify constants (key: '%s')"):format(key))
    end
})
