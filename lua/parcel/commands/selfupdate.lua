local selfupdate_command = {}

---@param options vim.api.keyset.create_user_command.command_args
function selfupdate_command.run(options)
    local packinfo = vim.pack.get({ "parcel" })

    if #packinfo == 0 then
        require("parcel.notify").warn("parcel.nvim is not managed by vim.pack, cannot update")
        return
    end

    vim.pack.update({ packinfo[1].spec.name })
end

return selfupdate_command
