-- local parcels = {
--     Parcel:new({
--         state = "installed",
--         issues_url = "https://github.com/issues",
--         pulls_url = "https://github.com/pulls",
--         source_type = "git",
--         spec = Spec:new({
--             name = "decipher.nvim",
--             version = "1.0.0",
--             source = "git://github.com/neovim/nvim-lspconfig.git",
--             pinned = false,
--             dev = true,
--             dependencies = {
--                 { name = "plenary.nvim", version = ">= 0.6.1" },
--                 { name = "neotest", version = "4.2.6" },
--             },
--             external_dependencies = {
--                 { name = "git", version = ">= 5.3.4" },
--             }
--         }, "git"),
--         packspec = Packspec:new({
--             package = "nvim-lspconfig",
--             source = "git://github.com/neovim/nvim-lspconfig.git",
--             description = {
--                 license = "BSD3",
--             },
--             dependencies = {
--                 {
--                     source = "git://github.com/someone/plenary.nvim.git",
--                     version = "< 1.2.4",
--                 },
--                 {
--                     source = "git://github.com/someonelse/neotest.git",
--                     version = "1.3.5",
--                 },
--             },
--             external_dependencies = {
--                 git = ">= 5.3.4",
--             },
--         }),
--     }),
--     Parcel:new({
--         state = "loaded",
--         issues_url = "https://luarocks.com/issues",
--         pulls_url = "https://luarocks.com/pulls",
--         source_type = "luarocks",
--         spec = Spec:new({
--             name = "fzf-lua",
--             pinned = true,
--             dev = false,
--             version = "0.2.1",
--         }, "git"),
--         packspec = Packspec:new({
--             package = "fzf-lua",
--             source = "https://luarocks.com",
--             description = {
--                 summary = "fzf changed my command life, it can change yours too, if you allow it.",
--                 license = "MIT",
--             },
--             dependencies = {},
--             external_dependencies = { { name = "git", version = ">= 5.3.4" } }
--         }),
--     }),
-- }

local subcommands = {
    log = true,
    clean = true,
    update = true,
    selfupdate = true,
    prune = true,
}

local function complete()
    return vim.tbl_keys(subcommands)
end

local function run_command(options)
    local args = options.fargs
    local subcommand = table.remove(args, 1)

    if subcommand then
        local notify = require("parcel.notify")
        local action = subcommands[subcommand]

        if action then
            require("parcel.commands." .. subcommand).run(options)
        else
            notify.warn("no such subcommand: '%s'", subcommand)
        end
    else
        local overview = require("parcel.ui").Overview.main({
            float = args[2] == "float",
            mods = options.mods,
        })

        overview:render()
    end
end

vim.api.nvim_create_user_command("Parcel", run_command, {
    nargs = "?",
    complete = complete
})
