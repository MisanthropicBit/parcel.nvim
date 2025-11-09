local extmark = {}

local constants = require("parcel.constants")
local highlight = require("parcel.highlight")

---@class parcel.ExtmarkSpec
---@field [1] string
---@field fg  string?
---@field bg  string?

---@param buffer integer
---@param row integer
---@param col integer
---@param specs parcel.ExtmarkSpec[]
function extmark.create(buffer, row, col, specs)
    local extmark_ids = {}
    local cur_col = col
    vim.print(constants.namespace)

    for _, spec in ipairs(specs) do
        local start_col = cur_col
        local end_col = cur_col + vim.fn.strlen(spec[1])
        local hl_group = highlight.create({ fg = spec.fg, bg = spec.bg })

        vim.print(hl_group)

        local id = vim.api.nvim_buf_set_extmark(
            buffer,
            constants.namespace,
            row,
            start_col,
            { end_col = end_col, hl_group = hl_group }
        )

        cur_col = end_col

        table.insert(extmark_ids, id)
    end

    return extmark_ids
end

return extmark
