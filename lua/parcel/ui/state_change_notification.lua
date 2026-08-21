---@alias parcel.ChangeNotifcation parcel.StateChangeNotification | parcel.StateUpdateAvailableNotification

---@class parcel.StateChangeNotification
---@field type  "state"
---@field name  string
---@field state parcel.State

---@class parcel.StateUpdateAvailableNotification
---@field type "update_available"
---@field parcel parcel.Parcel
