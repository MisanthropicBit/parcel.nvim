local install = {}

local Parcel = require("parcel.parcel")
local Spec = require("parcel.spec")
local state = require("parcel.state")

---@param user_spec parcel.Spec
---@param source parcel.Source
---@return boolean
---@return boolean
---@return parcel.Parcel?
return function(user_spec, source)
    local spec = Spec:new(user_spec, source:name())
    local new_parcel = Parcel:new({ spec = spec })
    local spec_ok = spec:validate()
    local install_ok, result

    if not spec_ok then
        new_parcel:set_state(Parcel.State.Failed)
    else
        install_ok, result = pcall(source.install, new_parcel)

        if not install_ok or not result then
            new_parcel:set_state(Parcel.State.Failed)
        else
            new_parcel:set_state(Parcel.State.Installed)
        end
    end

    -- Add the parcel to the state so the user can see any errors in the ui
    state.add_parcel(new_parcel)

    return spec_ok, install_ok, new_parcel
end
