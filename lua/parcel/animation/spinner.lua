local Animation = require("parcel.animation.animation")

---@class parcel.Spinner: parcel.Animation
local Spinner = {}

---@param frames string[]
---@param callback fun(frame: string)
---@param options parcel.AnimationOptionsNoCallback
function Spinner.new(frames, callback, options)
    return Animation.text(frames, callback, vim.tbl_extend("force", options, { loop = true }))
end

return Spinner
