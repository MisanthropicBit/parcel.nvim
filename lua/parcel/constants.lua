local Path = require("parcel.path")

local values = {
    augroup = vim.api.nvim_create_augroup("parcel.augroup", {}),
    namespace = vim.api.nvim_create_namespace("parcel"),
    hl_namespace = vim.api.nvim_create_namespace("parcel.hl"),
    extmark_namespace = vim.api.nvim_create_namespace("parcel.extmark"),
    select_hl_namespace = vim.api.nvim_create_namespace("parcel.hl.select"),
    packlog = Path.new(vim.fn.stdpath("log"), "nvim-pack.log"),
    lockfile = Path.new(vim.fn.stdpath("config"), "nvim-pack-lock.json."),
    version = "0.1.0",
}

return setmetatable({}, {
    __index = values,
    __new_index = function(_, key)
        error(("Cannot modify constants (key: '%s')"):format(key))
    end
})
