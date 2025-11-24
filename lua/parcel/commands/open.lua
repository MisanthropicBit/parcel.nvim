local open_command = {}

function open_command.run(options)
    local overview = require("parcel.ui").Overview.main()

    -- TODO: Open hidden buffer is there
    if not overview:focus() then
        overview:open({
            float = options.fargs[2] == "float",
            mods = options.mods,
        })

        overview:render()
    end
end

return open_command
