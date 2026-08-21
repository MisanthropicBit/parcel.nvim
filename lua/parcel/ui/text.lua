local highlight = require("parcel.highlight")

---@alias parcel.ui.Data table<string, unknown> Arbitrary data associated with an extmark

---@class parcel.ui.TextElement
---@field [1]  string
---@field hl   parcel.ui.Highlight?
---@field data parcel.ui.Data?

---@alias parcel.ui.TextOptions string | parcel.ui.TextElement | parcel.ui.TextElement[]

---@class parcel.ui.LabelOptions
---@field left_sep  string?
---@field right_sep string?
---@field text      string
---@field spacing   integer?
---@field hl        parcel.ui.Highlight

---@class parcel.ui.Text: parcel.ui.BaseElement
---@field _values      string[]
---@field _highlights  parcel.ui.HighlightGroup[]
---@field _extmark_ids (integer?)[]
---@field _data        table<integer, parcel.ui.Data>
local Text = {}

Text.__index = Text

local constants = require("parcel.constants")

local text_defaults = {}

---@param options parcel.ui.TextOptions
---@return parcel.ui.Text
function Text.new(options)
    local text = {}

    text._values = {}
    text._highlights = {}
    text._extmark_ids = {}
    text._data = {}

    local elements

    ---@diagnostic disable-next-line: param-type-mismatch
    if vim.islist(options) then
        ---@cast options (string | parcel.ui.TextElement)[]
        elements = vim.tbl_map(function(element)
            return type(element) == "string" and { element } or element
        end, options)
    else
        elements = { options }
    end

    ---@cast elements (string | parcel.ui.TextElement)[]
    for idx, value in ipairs(elements) do
        table.insert(text._values, value[1])
        text._data[idx] = value.data

        local hl

        if value.hl then
            hl = highlight.create(value.hl)
        elseif value.data then
            -- If there is custom data but no highlight, force an extmark so we
            -- can find the cell if the cursor is on it
            hl = highlight.create({ fg = "NONE" })
        end

        table.insert(text._highlights, hl or "")
    end

    return setmetatable(text, Text)
end

---@return integer
function Text:size()
    return #self:render()[1]
end

---@return string[]
function Text:render()
    return { table.concat(self._values) }
end

---@param buffer integer
---@param row integer
---@param col integer
---@return integer
function Text:set_highlight(buffer, row, col)
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

            self._extmark_ids[idx] =
                vim.api.nvim_buf_set_extmark(buffer, constants.extmark_namespace, row, cur_col, extmark)
        end

        cur_col = end_col
    end

    return row + 1
end

---@return table<integer, parcel.ui.Data>
function Text:data()
    return self._data
end

---@param buffer integer
---@param row integer
---@param col integer
---@return parcel.ui.Data?
function Text:element_at(buffer, row, col)
    for idx, extmark_id in ipairs(self._extmark_ids) do
        local result = vim.api.nvim_buf_get_extmark_by_id(buffer, constants.extmark_namespace, extmark_id, {
            details = true,
        })

        if result then
            local erow, ecol, details = result[1], result[2], result[3]
            ---@cast details -nil

            if #self._values > 1 then
                vim.print(vim.inspect(self._values))
                vim.print(vim.inspect({ buffer, row, col }))
                vim.print(vim.inspect({ row, erow, details.end_row, col, ecol, details.end_col }))
            end

            if row >= erow and row <= details.end_row and col >= ecol and col <= details.end_col then
                return self._data[idx]
            end
        end
    end
end

--- Create a text element from a list of delimited parts
---@param parts (string | parcel.ui.TextElement)[]
---@param delimiter string | parcel.ui.TextElement
function Text.delimited(parts, delimiter)
    local delimited = {}

    for idx = 1, #parts do
        table.insert(delimited, parts[idx])

        if idx < #parts then
            table.insert(delimited, delimiter)
        end
    end

    return Text.new(delimited)
end

-- Label inspired by Snacks.gh badges
---@param options parcel.ui.LabelOptions
function Text.label(options)
    -- TODO: Check if both seps are given or missing
    -- TODO: Get fg and bg from highlight group or use those given
    local spacing = (" "):rep(options.spacing or 0)
    local text = ("%s%s%s"):format(spacing, options.text, spacing)

    return Text.new({
        { options.left_sep or "", hl = { fg = options.hl.bg } },
        { text, hl = options.hl },
        { options.right_sep or "", hl = { fg = options.hl.bg } },
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
