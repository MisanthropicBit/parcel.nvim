local lazy_require = require("parcel.utils.lazy_require")

-- TODO: Update ui elements to have prefix parcel.ui.X

---@alias parcel.UiElement parcel.ui.Grid | parcel.Label

---@class parcel.ui.RenderOptions
---@field buffer integer
---@field max_cell_widths integer[]

return {
    Cell = lazy_require.lazy_require("parcel.ui.cell"),
    Grid = lazy_require.lazy_require("parcel.ui.grid"),
    Label = lazy_require.lazy_require("parcel.ui.label"),
    Lines = lazy_require.lazy_require("parcel.ui.lines"),
    Overview = lazy_require.lazy_require("parcel.ui.overview"),
    Row = lazy_require.lazy_require("parcel.ui.row"),
    Section = lazy_require.lazy_require("parcel.ui.section"),
}
