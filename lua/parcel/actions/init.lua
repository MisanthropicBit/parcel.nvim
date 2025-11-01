local actions = {}

---@param user_spec parcel.Spec
---@param source parcel.Source
---@return boolean
---@return boolean
---@return parcel.Parcel?
function actions.install_parcel(user_spec, source)
    return require("parcel.actions.install")(user_spec, source)
end

function actions.update_parcel(user_spec, source, installed_parcel)
    return require("parcel.actions.update")(user_spec, source, installed_parcel)
end

function actions.update_parcel_from_spec(user_spec, source, installed_parcel)
    return require("parcel.actions.update_from_spec")(user_spec, source, installed_parcel)
end

function actions.update_parcels_from_spec(specs)
    return require("lua.parcel.actions.update_parcels_from_spec")(specs)
end

function actions.uninstall_parcel(source, installed_parcel)
    return require("parcel.actions.uninstall")(source, installed_parcel)
end

return actions
