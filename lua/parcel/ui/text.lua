local highlight = require("parcel.highlight")

---@class parcel.ui.TextElement
---@field [1] string
---@field hl  parcel.ui.Highlight?

---@alias parcel.ui.TextOptions string | parcel.ui.TextElement | parcel.ui.TextElement[]

---@class parcel.ui.LabelOptions
---@field left_sep  string?
---@field right_sep string?
---@field text      string
---@field spacing   integer?
---@field hl        parcel.ui.Highlight

---@class parcel.ui.Text
---@field _values      string[]
---@field _highlights  parcel.ui.HighlightGroup[]
---@field _extmark_ids integer?[]
local Text = {}

Text.__index = Text

local config = require("parcel.config")

local text_defaults = {}

---@param options parcel.ui.TextOptions
---@return parcel.ui.Text
function Text.new(options)
    local text = vim.tbl_deep_extend("force", text_defaults, options)

    text._values = {}
    text._highlights = {}
    text._extmark_ids = {}

    if type(options) == "string" then
        table.insert(text._values, options)
        table.insert(text._highlights, "")
    elseif options.hl ~= nil then
        table.insert(text._values, options[1])
        table.insert(text._highlights, highlight.create(options.hl))
    else
        for _, value in ipairs(options) do
            ---@cast value parcel.ui.TextElement
            table.insert(text._values, value[1])
            table.insert(text._highlights, value.hl and highlight.create(value.hl) or "")
        end
    end

    return setmetatable(text, Text)
end

---@return integer
function Text:size()
    return #self:render()
end

---@return string[]
function Text:render()
    return { table.concat(self._values) }
end

---@param row integer
---@param col integer
---@return integer
function Text:set_highlight(row, col)
    local cur_col = col

    for idx, hl in ipairs(self._highlights) do
        local value = self._values[idx]
        local end_col = cur_col + vim.fn.strlen(value)

        if value and #value > 0 and #hl > 0 then
            local extmark = {
                id = self._extmark_ids[idx],
                hl_group = hl,
                end_row = row,
                end_col = end_col,
            }

            -- TODO: Set buffer
            vim.print(vim.inspect({ self._values[idx], row, row, cur_col, end_col }))
            self._extmark_ids[idx] = vim.api.nvim_buf_set_extmark(0, config.namespace, row, cur_col, extmark)
        end

        cur_col = end_col
    end

    return row
end

---@param options parcel.ui.LabelOptions
function Text.label(options)
    local spacing = (" "):rep(options.spacing or 0)
    local text = ("%s%s%s"):format(spacing, options.text, spacing)

    return Text.new({
        { options.left_sep or "", hl = options.hl },
        { text, fg = "#ffffff", hl = options.hl },
        { options.right_sep or "", hl = options.hl },
    })
end

function Text.label_slanted_right(text, hl)
    return Text.label({
        text = text,
        left_sep = " ",
        right_sep = " ",
        hl = hl,
    })
end

return Text
