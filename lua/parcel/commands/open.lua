local open = {}

function open.run(options)
    local overview = require("parcel.ui").Overview.main({
        open = true,
        float = options.fargs[2] == "float",
        mods = options.mods,
    })
end

return open
