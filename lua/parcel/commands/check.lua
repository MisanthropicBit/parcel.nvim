local check_command = {}

local update_checker = require("parcel.update_checker")
local state = require("parcel.state")

---@param options vim.api.keyset.create_user_command.command_args
function check_command.run(options)
    update_checker.check(state.parcel_list())
end

return check_command
