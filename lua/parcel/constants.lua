local values = {
    augroup = vim.api.nvim_create_augroup("parcel.augroup", {}),
    namespace = vim.api.nvim_create_namespace("parcel"),
    lockfile = vim.fn.stdpath("config") .. "/nvim/nvim-pack-lock.json.",
    version = "0.1.0",
}

return setmetatable({}, {
    __index = values,
    __new_index = function(_, key)
        error(("Cannot modify constants (key: '%s')"):format(key))
    end
})
