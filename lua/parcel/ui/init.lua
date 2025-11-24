local lazy_require = require("parcel.utils.lazy_require")

---@enum parcel.ui.Column
local Column = {
    State = "state",
    PackageIcon = "package_icon",
    Name = "name",
    VersionRevision = "version_revision",
}

---@alias parcel.ui.Element parcel.ui.Grid | parcel.ui.Text

---@alias parcel.ui.InlineElement parcel.ui.Text Elements that can appear on the same line in a parcel.ui.Lines

---@alias parcel.ui.HighlightGroup string A vim/neovim highlight group name such as "Special"

---@alias parcel.ui.HighlightSpec vim.api.keyset.highlight Same as value passed to vim.api.nvim_set_hl

---@alias parcel.ui.Highlight parcel.ui.HighlightGroup | parcel.ui.HighlightSpec

---@class parcel.ui.RenderOptions
---@field buffer integer
---@field max_cell_widths integer[]

return {
    Cell = lazy_require.lazy_require("parcel.ui.cell"),
    Grid = lazy_require.lazy_require("parcel.ui.grid"),
    Lines = lazy_require.lazy_require("parcel.ui.lines"),
    Overview = lazy_require.lazy_require("parcel.ui.overview"),
    Row = lazy_require.lazy_require("parcel.ui.row"),
    Section = lazy_require.lazy_require("parcel.ui.section"),
    Text = lazy_require.lazy_require("parcel.ui.text"),
}
