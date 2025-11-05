local lazy_require = require("parcel.utils.lazy_require")

return {
    Column = lazy_require.lazy_require("parcel.ui.column"),
    Grid = lazy_require.lazy_require("parcel.ui.grid"),
    Label = lazy_require.lazy_require("parcel.ui.label"),
    Lines = lazy_require.lazy_require("parcel.ui.lines"),
    Overview = lazy_require.lazy_require("parcel.ui.overview"),
    Row = lazy_require.lazy_require("parcel.ui.row"),
    Section = lazy_require.lazy_require("parcel.ui.section"),
}
