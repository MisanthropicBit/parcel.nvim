local float_command = {}

function float_command.run(options)
    require("parcel.commands.open").run(
        vim.tbl_extend(
            "force",
            options,
            { fargs = { "float" } }
        )
    )
end

return float_command
