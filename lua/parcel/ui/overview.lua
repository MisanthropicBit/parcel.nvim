local actions = require("parcel.actions")
local compat = require("parcel.compat")
local config = require("parcel.config")
local icons = require("parcel.icons")
local Grid = require("parcel.ui.grid")
local Lines = require("parcel.ui.lines")
local async_utils = require("parcel.tasks.async_utils")
local sources = require("parcel.sources")

---@type table<string, any>
local window_options = {
    wrap = false,
    number = false,
    relativenumber = false,
    cursorline = false,
    signcolumn = "no",
    foldenable = false,
    spell = false,
    list = false,
}

---@type table<string, any>
local buffer_options = {
    buftype = "nofile",
    bufhidden = "wipe",
    buflisted = false,
    -- modifiable = false,
    filetype = "parcel-overview",
}

---@class parcel.Section
---@field visible boolean
---@field section parcel.Lines

---@class parcel.OverviewOptions
---@field float boolean? open the overview in a float if true
---@field mods string? any split modifiers such as "vertical"

---@class parcel.Overview
---@field lines parcel.Lines
---@field parcels_by_extmark table<integer, parcel.Parcel>
---@field selected table<integer, boolean>
---@field sections table<integer, parcel.Section>
---@field parcels parcel.Parcel[]
local Overview = {}

Overview.__index = Overview

---@param parcels parcel.Parcel[]
---@return parcel.Overview
function Overview:new(parcels)
    return setmetatable({
        lines = Lines:new(),
        parcels_by_extmark = {},
        selected = {},
        sections = {},
        parcels = parcels or {},
        timer = nil,
    }, Overview)
end

---@param _options parcel.OverviewOptions?
function Overview:init(_options)
    local _options = _options or {}

    if _options.float then
        self.buffer = vim.api.nvim_create_buf(false, false)
        self.win_id = vim.api.nvim_open_win(self.buffer, true, {})
    else
        vim.cmd((_options.mods or "") .. " new")
        self.buffer = vim.api.nvim_win_get_buf(0)
        self.win_id = vim.api.nvim_get_current_win()
    end

    -- Set default window options
    for option, value in pairs(window_options) do
        vim.api.nvim_win_set_option(self.win_id, option, value)
    end

    -- Set default buffer options
    for option, value in pairs(buffer_options) do
        vim.api.nvim_buf_set_option(self.buffer, option, value)
    end

    local mappings = config.ui.mappings

    -- self:on_key(mappings.pin, function(_self, parcel, row_idx)
    --     if parcel then
    --         parcel:toggle_pinned()
    --         _self:update(row_idx)
    --     end
    -- end)

    self:on_key(mappings.disable, function(_self, parcel, row_idx)
        if parcel then
            -- loader:disable(parcel)
            _self:update(row_idx)
        end
    end)

    self:on_key(mappings.expand, function(_self, parcel)
        if parcel then
            _self:toggle_expand(parcel)
            -- self:update(row_idx)
        end
    end)

    self:on_key(mappings.previous, function(_self, parcel, lnum)
        if parcel then
            local extmark = _self.grid:get_prev_extmark(lnum)

            if extmark then
                vim.api.nvim_win_set_cursor(_self.win_id, { extmark.lnum, 1 })
            end
        end
    end)

    self:on_key(mappings.next, function(_self, parcel, lnum)
        if parcel then
            local extmark = _self.grid:get_next_extmark(lnum)

            if extmark then
                vim.api.nvim_win_set_cursor(_self.win_id, { extmark.lnum, 1 })
            end
        end
    end)

    self:on_key(mappings.collapse_all, function(_self)
        for highlight_id, expanded in pairs(self.sections) do
            ---@diagnostic disable-next-line: invisible
            local lnum = self.parcels_by_extmark[highlight_id]._highlight.lnum

            if expanded.visible then
                expanded.section:clear(self.buffer, lnum + 1)
            end

            expanded.visible = false
        end
    end)

    -- self:on_key(mappings.install, function(_self, parcel)
    --     if parcel then
    --         if parcel:state() == "installed" then
    --             return
    --         end

    --         -- TODO: Refactor this out into an update timer or separate methods
    --         local frame_idx = 1
    --         local id = parcel._highlight.id
    --         local row = _self.grid:get_row_for_extmark_id(id)

    --         local animate_icon = vim.schedule_wrap(function()
    --             local update_icon = icons.get_animation_frame(
    --                 config.ui.icons.updating,
    --                 frame_idx
    --             )

    --             -- TODO: Throttle calls to render
    --             -- TODO: Make a utility method in this class to render a grid position
    --             -- and then throttle it as well
    --             _self.grid:render_by_extmark(id, update_icon, row, 1)

    --             frame_idx = frame_idx + 1
    --         end)

    --         local on_finish_install = vim.schedule_wrap(function()
    --             parcel:set_state("installed")
    --             _self.grid:render_by_extmark(id, config.ui.icons.installed, row, 1)
    --         end)

    --         local timer = uv.new_timer()
    --         parcel:set_state("updating")

    --         timer:start(0, 100, function()
    --             animate_icon()

    --             if frame_idx > 20 then
    --                 on_finish_install()
    --                 timer:stop()
    --             end
    --         end)

    --         -- actions.install.run({ parcel }, {
    --         --     callback = function()
    --         --         if parcel._installed then
    --         --             _self.grid:set_cell(config.ui.icons[parcel:state()], parcel._grid_row, 1)
    --         --             _self.grid:render_by_extmark(parcel._highlight.id)
    --         --         end
    --         --     end
    --         -- })
    --     end
    -- end)

    -- self:on_key(mappings.explain, function(parcel, row_idx)
    --     if parcel then
    --         self:explain(row_idx)
    --     end
    -- end)

    -- self:on_key(mappings.update, function(parcel, row_idx)
    --     if parcel then
    --         self:update_parcels(row_idx, self.selected)
    --     end
    -- end)

    -- self:on_key(mappings.update_all, function(parcel)
    --     if parcel then
    --         self:update_parcels()
    --     end
    -- end)

    -- self.update = async_utils.throttle(100, self.update)

    -- Set an autocommand to update the self from asynchronous tasks
    vim.api.nvim_create_autocmd(
        "User",
        {
            pattern = "ParcelRender",
            callback = function()
                self:update()
            end
        }
    )

    self.grid = Grid:new({
        buffer = self.buffer,
        lnum = self.parcel_row_offset,
    })
end

function Overview:notify(type, parcel)
    -- TODO: Return if not visible

    if not self.timer then
        self.timer = compat.loop.new_timer()
    end
end

---@param parcel parcel.Parcel
function Overview:toggle_expand(parcel)
    ---@diagnostic disable-next-line: invisible
    local id = parcel._highlight.id
    ---@diagnostic disable-next-line: invisible
    local lnum = parcel._highlight.lnum

    local section = self.sections[id]
    section.visible = not section.visible

    if section.visible then
        section.section:render(self.buffer, lnum + 1)
    else
        section.section:clear(self.buffer, lnum + 1)
    end

    -- Set cursor position to the toggled parcel's row
    vim.api.nvim_win_set_cursor(self.win_id, { lnum, 0 })
end

---@param parcel parcel.Parcel
---@return table[]
function Overview:create_parcel_columns(parcel)
    local highlights = config.ui.highlights
    local _icons = config.ui.icons
    local source_type_icon = _icons.sources[parcel:source()] or _icons.sources.unknown_source

    return {
        {
            _icons[parcel:state()],
            rpad = 2,
            hl = highlights[parcel:state()],
        },
        {
            _icons.parcel,
            rpad = 2,
            hl = highlights.parcel,
        },
        {
            source_type_icon,
            rpad = 1,
            hl = "Special",
        },
        {
            parcel:name(),
            align = "left",
            pad = "auto",
            min_pad = 1,
            hl = "String",
        },
        {
            parcel:version(),
            rpad = 1,
            hl = "Type",
        },
        {
            parcel:pinned(),
            icon = _icons.pinned,
            hl = highlights.pinned,
            rpad = 1,
        },
        {
            parcel:local_development(),
            icon = _icons.dev,
            hl = highlights.dev,
        },
    }
end

---@param lnum integer
function Overview:set_parcel_row(lnum)
    local parcel = self:get_parcel_at_cursor(lnum)

    if not parcel then
        return
    end

    self.grid:row(lnum):set_columns(self:create_parcel_columns(parcel))
end

--- Update the overview
---@param lnum? integer
function Overview:update(lnum)
    if lnum ~= nil then
        self:set_parcel_row(lnum)
        return
    end

    self.lines = Lines:new()
    self.lines:add("Parcels", "Title")
    self.lines:add((" (%d)"):format(#self.parcels), "Title"):newline():newline()
    self.lines:add("Press g? for help.", "Comment"):newline():newline()
    self.parcel_row_offset = self.lines:row()

    if #self.parcels == 0 then
        self.lines:add("No parcels specified, please call parcel.setup")
        return
    end

    self.grid = Grid:new({
        buffer = self.buffer,
        lnum = self.parcel_row_offset,
    })

    for idx, parcel in ipairs(self.parcels) do
        self.grid:add_row(self:create_parcel_columns(parcel))
        parcel._grid_row = idx
    end

    self.lines:add(self.grid)
end

---@param text string
---@param placeholder string?
---@return string
function Overview:format_text(text, placeholder)
    if text ~= nil and #text > 0 then
        return text
    else
        return placeholder or "———"
    end
end

function Overview:add_source_section(parcel, section)
    local _icons = config.ui.icons
    local section_bullet = _icons.section_bullet
    local source = sources.get_source(parcel:source())

    ---@cast source -nil

    source.write_section(parcel, section)
end

---@param parcel parcel.Parcel
function Overview:add_subsection(parcel, offset)
    -- local indent = self.grid:column_offset(2)
    local _icons = config.ui.icons
    -- local section_sep = _icons.section_sep
    local section_bullet = _icons.section_bullet
    local section_double_bullet = _icons.section_sep .. _icons.dash

    local section = Lines:new({
        offset = offset,
        indent = 2, -- indent,
        -- TODO: Highlight sep
        -- sep = section_sep .. " ",
    })

    if parcel:state() ~= parcel.State.Installed then
        section
            :newline()
            :add("Not installed", "ErrorMsg", { sep = section_bullet })
            :newline()

        section
            :newline()
            :add("")

        return section
    end

    section:newline()

    if parcel:description() then
        section:add(parcel:description()):newline():newline()
    end

    self:add_source_section(parcel, section)

    section
        :add(
            "Source          ",
            "Keyword", -- "ParcelSectionSource",
            { sep = section_bullet }
        )
        :add(parcel:source())
        :newline()

    local deps = parcel:dependencies()

    section
        :newline()
        :add(
            "Dependencies (%d)",
            "Label",
            {
                sep = section_double_bullet,
                args = { #deps },
            }
        )
        :newline()
        :newline()

    local dep_grid = Grid:new({
        buffer = self.buffer,
        indent = 1,--indent,
        sep = _icons.section_sep .. " ",
    })

    if deps then
        for _, dep in ipairs(deps) do
            dep_grid:add_row({
                { _icons.parcel .. " " .. (dep.name or dep.source), min_pad = 5 },
                { dep.version, align = "right" },
            })
        end
    end

    local ext_deps = parcel:external_dependencies()

    section
        :add(dep_grid)
        :newline()
        :newline(#deps > 0)
        :add(
            "External dependencies (%d)",
            "Label",
            {
                sep = section_double_bullet,
                args = { #ext_deps },
            }
        )
        :newline(#ext_deps > 0)
        :newline()

    local ext_dep_grid = Grid:new({
        indent = 1,--indent,
        sep = _icons.section_sep .. " ",
    })

    for _, dep in ipairs(ext_deps) do
        ext_dep_grid:add_row({
            { _icons.external_dependency .. " " .. dep.name, min_pad = 5 },
            { dep.version, align = "right" },
        })
    end

    section:add(ext_dep_grid):newline()

    return section
end

---@param lnum integer
---@return parcel.Parcel?
function Overview:get_parcel_at_cursor(lnum)
    local highlight = self.grid:get_nearest_extmark(lnum)

    if not highlight then
        return nil
    end

    local parcel = self.parcels_by_extmark[highlight.id]
    ---@diagnostic disable-next-line: invisible
    parcel._highlight = highlight
    ---@diagnostic disable-next-line: invisible
    parcel._highlight.lnum = highlight.lnum

    return parcel
end

---@param key string
---@param callback fun(overview: parcel.Overview, parcel: parcel.Parcel, lnum: integer, col: integer)
function Overview:on_key(key, callback)
    local wrapped = function()
        local lnum = vim.fn.line(".")
        local parcel = self:get_parcel_at_cursor(lnum)
        ---@cast parcel -nil

        callback(self, parcel, lnum, vim.fn.col("."))
    end

    -- TODO: Use compat
    vim.keymap.set("n", key, wrapped, { buffer = self.buffer })
end

function Overview:update_extmarks()
    if not self.grid then
        return
    end

    -- After the first render, map extmarks for each parcel so we can easily
    -- find the nearest parcel under the cursor
    for idx, extmark in ipairs(self.grid:get_line_extmarks()) do
        local parcel = self.parcels[idx]
        local id = extmark.id

        ---@diagnostic disable-next-line: invisible
        parcel._highlight = extmark
        self.parcels_by_extmark[id] = parcel

        if not self.sections[id] then
            self.sections[id] = {
                visible = false,
                section = self:add_subsection(parcel, self.parcel_row_offset + idx - 1),
            }
        end
    end
end

function Overview:render(row_idx)
    self.lines:render(self.buffer)
    self:update_extmarks()
end

return Overview
