local lazy_require = require("parcel.utils.lazy_require")

-- TODO: Update ui elements to have prefix parcel.ui.X

---@alias parcel.UiElement parcel.Grid | parcel.Label

---@class parcel.RenderOptions
---@field max_len integer

return {
    Cell = lazy_require.lazy_require("parcel.ui.cell"),
    Grid = lazy_require.lazy_require("parcel.ui.grid"),
    Label = lazy_require.lazy_require("parcel.ui.label"),
    Lines = lazy_require.lazy_require("parcel.ui.lines"),
    Overview = lazy_require.lazy_require("parcel.ui.overview"),
    Row = lazy_require.lazy_require("parcel.ui.row"),
    Section = lazy_require.lazy_require("parcel.ui.section"),
}
