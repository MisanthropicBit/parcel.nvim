local subcommands = {
    check = true,
    float = true,
    log = true,
    packlog = true,
    selfupdate = true,
    version = true,
}

local function complete()
    return vim.tbl_keys(subcommands)
end

---@param options vim.api.keyset.create_user_command.command_args
local function run_command(options)
    require("parcel").setup()

    local fargs = options.fargs
    local subcommand = table.remove(fargs, 1)

    if subcommand then
        local ok, action_or_error = pcall(require, "parcel.commands." .. subcommand)

        if ok then
            action_or_error.run(options)
        else
            require("parcel.notify").warn("no such subcommand: '%s'", subcommand)
        end
    else
        require("parcel.commands.open").run(options)
    end
end

vim.api.nvim_create_user_command("Parcel", run_command, {
    nargs = "?",
    complete = complete
})
