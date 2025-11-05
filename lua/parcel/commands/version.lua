local version = {}

local constants = require("parcel.constants")
local notify = require("parcel.notify")

---@param options vim.api.keyset.create_user_command.command_args
function version.run(options)
    notify.info("Parcel version %s", constants.version)
end

return version
