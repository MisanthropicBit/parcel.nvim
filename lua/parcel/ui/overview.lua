local actions = require("parcel.actions")
local config = require("parcel.config")
local icons = require("parcel.icons")
local Grid = require("parcel.ui.grid")
local Lines = require("parcel.ui.lines")

local uv = vim.loop

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

---@class parcel.Overview
---@field lines parcel.Lines
---@field parcels_by_extmark table<integer, parcel.Parcel>
---@field selected table<integer, boolean>
---@field expanded table<integer, table>
---@field parcels parcel.Parcel[]
local Overview = {}

---@param parcels parcel.Parcel[]
---@return parcel.Overview
function Overview:new(parcels)
    local overview = {
        lines = Lines:new(),
        parcels_by_extmark = {},
        selected = {},
        expanded = {},
        parcels = parcels or {},
    }

    self.__index = self

    return setmetatable(overview, self)
end

---@param options table
function Overview:init(options)
    if options.float then
        self.buffer = vim.api.nvim_create_buf(false, false)
        self.win_id = vim.api.nvim_open_win(self.buffer, true, {})
    else
        vim.cmd((options.mods or "") .. " new")
        self.buffer = vim.api.nvim_win_get_buf(0)
        self.win_id = vim.api.nvim_get_current_win()
    end

    -- Set default window options
    vim.print(self.win_id)
    for option, value in pairs(window_options) do
        vim.api.nvim_win_set_option(self.win_id, option, value)
    end

    -- Set default buffer options
    for option, value in pairs(buffer_options) do
        vim.api.nvim_buf_set_option(self.buffer, option, value)
    end

    local mappings = config.ui.mappings

    self:on_key(mappings.pin, function(_self, parcel, row_idx)
        if parcel then
            parcel.spec.pinned = not parcel.spec.pinned
            _self:update(row_idx)
        end
    end)

    self:on_key(mappings.disable, function(_self, parcel, row_idx)
        if parcel then
            parcel.spec.disabled = not parcel.spec.disabled
            vim.print(_self)
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
        for highlight_id, expanded in pairs(self.expanded) do
            local lnum = self.parcels_by_extmark[highlight_id]._highlight.lnum

            if expanded.visible then
                expanded.section:clear(self.buffer, lnum + 1)
            end

            expanded.visible = false
        end
    end)

    self:on_key(mappings.install, function(_self, parcel)
        if parcel then
            if parcel.state == "installed" then
                return
            end

            local frame_idx = 1
            local timer = uv.new_timer()

            local animate_icon = vim.schedule_wrap(function()
                local update_icon = icons.get_animation_frame(config.ui.icons.updating, frame_idx)
                _self.grid:set_cell(update_icon, 1, 1)

                -- TODO: Re-render only the affected line
                -- TODO: Throttle calls to render
                _self:render()

                frame_idx = frame_idx + 1
            end)

            local on_finish_install = vim.schedule_wrap(function()
                parcel.state = "installed"
                _self.grid:set_cell(config.ui.icons.installed, 1, 1)
                _self:render()
            end)

            parcel.state = "updating"

            timer:start(0, 100, function()
                animate_icon()

                if frame_idx > 10 then
                    on_finish_install()
                    timer:stop()
                end
            end)

            -- actions.install.run({ parcel }, {
            --     callback = function()
            --         if parcel._installed then
            --             _self.grid:set_cell(config.ui.icons[parcel.state], parcel._grid_row, 1)
            --             _self.grid:render_by_extmark(parcel._highlight.id)
            --         end
            --     end
            -- })
        end
    end)

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

    self.grid = Grid:new({ buffer = self.buffer, lnum = self.parcel_row_offset })
end

---@param parcel parcel.Parcel
function Overview:toggle_expand(parcel)
    local id = parcel._highlight.id
    local lnum = parcel._highlight.lnum
    local expanded = self.expanded[id]

    expanded.visible = not expanded.visible

    if expanded.visible then
        expanded.section:render(self.buffer, lnum + 1)
    else
        expanded.section:clear(self.buffer, lnum + 1)
    end

    -- Set cursor position to the toggled parcel's row
    vim.api.nvim_win_set_cursor(self.win_id, { lnum, 0 })
end

function Overview:create_parcel_columns(parcel)
    local state_highlight = {
        installed = "Conditional",
        not_installed = "",
        updating = "",
        updates_available = "",
        loaded = "diffAdded",
    }

    local icons = config.ui.icons
    local source_type_icon = icons[parcel:source()] or icons.unknown_source

    return {
        { icons[parcel.state], rpad = 2, hl = state_highlight[parcel.state] },
        { icons.parcel,        rpad = 2, hl = "Special" },
        { source_type_icon,    rpad = 1, hl = "Special" },
        { parcel:name(),         align = "left", pad = "auto", min_pad = 1, hl = "String" },
        { parcel:version(), rpad = 1, hl = "Type" },
        { parcel.spec.pinned,  icon = icons.pinned, hl = "Identifier", rpad = 1 },
        { parcel.spec.dev,     icon = icons.dev, hl = "Identifier" },
    }
end

function Overview:set_parcel_row(lnum)
    local parcel = self:get_parcel_at_cursor(lnum)

    self.grid.row(lnum):set_columns(self:create_parcel_columns(parcel))
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

    self.grid = Grid:new({ buffer = self.buffer, lnum = self.parcel_row_offset })

    for idx, parcel in ipairs(self.parcels) do
        self.grid:add_row(self:create_parcel_columns(parcel))
        parcel._grid_row = idx
    end

    self.lines:add(self.grid)
end

function Overview:format_text(text)
    if text ~= nil and #text > 0 then
        return text
    else
        return "———"
    end
end

function Overview:add_git_subsection(parcel, section)
    vim.print("Why is this called?")
    local icons = config.ui.icons
    local section_bullet = icons.section_bullet

    if parcel.spec.version then
        section
            :add(
                "Version         ",
                "Keyword", -- ParcelSectionVersion",
                { sep = section_bullet }
            )
            :add(self:format_text(parcel.spec.version))
            :newline()
    end

    if parcel:license() ~= nil and #parcel:license() > 0 then
        section:add(
                "License         ",
                "Keyword", -- "ParcelSectionLicense",
                { sep = section_bullet }
            )
            :add(self:format_text(parcel:license()))
            :newline()
    end

    section
        :add(
            "Issues          ",
            "Keyword", -- "ParcelSectionIssues",
            { sep = section_bullet }
        )
        :add(parcel.issues_url)
        :newline()
        :add(
            "Pull requests   ",
            "Keyword", -- "ParcelSectionPulls",
            { sep = section_bullet }
        )
        :add(parcel.pulls_url)
        :newline()
end

---@param parcel parcel.Parcel
function Overview:add_subsection(parcel, offset)
    -- local indent = self.grid:column_offset(2)
    local icons = config.ui.icons
    local section_sep = icons.section_sep
    local section_bullet = icons.section_bullet
    local section_double_bullet = icons.section_sep .. icons.dash

    local section = Lines:new({
        offset = offset,
        indent = 2, -- indent,
        -- TODO: Highlight sep
        sep = section_sep .. " ",
    })

    if parcel.state ~= "installed" then
        section
            :newline()
            :add("Not installed", "ErrorMsg", { sep = section_bullet })
            :newline()

        return section
    end

    section:newline()

    if parcel.description then
        section:add(parcel:description()):newline():newline()
    end

    Overview["add_" .. parcel.spec.source ..  "_subsection"](self, parcel, section)

    section
        :add(
            "Source          ",
            "Keyword", -- "ParcelSectionSource",
            { sep = section_bullet }
        )
        :add(parcel:source())
        :newline()


    section
        :newline()
        :add(
            "Dependencies (%d)",
            "Label",
            {
                sep = section_double_bullet,
                args = { #(parcel.dependencies or {}) },
            }
        )
        :newline()
        :newline()

    local dep_grid = Grid:new({
        buffer = self.buffer,
        indent = 1,--indent,
        sep = icons.section_sep .. " ",
    })

    local deps = parcel.dependencies or {}

    if deps then
        for _, dep in ipairs(deps) do
            dep_grid:add_row({
                { icons.parcel .. " " .. (dep.name or dep.source), min_pad = 5 },
                { dep.version, align = "right" },
            })
        end
    end

    section
        :add(dep_grid)
        :newline()
        :newline(#deps > 0)
        :add(
            "External dependencies (%d)",
            "Label",
            {
                sep = section_double_bullet,
                args = { #parcel:external_dependencies() },
            }
        )
        :newline(#parcel.external_dependencies > 0)
        :newline()

    local ext_dep_grid = Grid:new({
        indent = 1,--indent,
        sep = icons.section_sep .. " ",
    })

    for _, dep in ipairs(parcel:external_dependencies()) do
        ext_dep_grid:add_row({
            { icons.external_dependency .. " " .. dep.name, min_pad = 5 },
            { dep.version, align = "right" },
        })
    end

    section:add(ext_dep_grid):newline()

    return section
end

function Overview:get_parcel_at_cursor(lnum)
    local highlight = self.grid:get_nearest_extmark(lnum)

    if not highlight then
        return nil
    end

    local parcel = self.parcels_by_extmark[highlight.id]
    parcel._highlight = highlight
    parcel._highlight.lnum = highlight.lnum

    return parcel
end

function Overview:on_key(key, callback)
    local wrapped = function()
        local lnum = vim.fn.line(".")
        local parcel = self:get_parcel_at_cursor(lnum)

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

        parcel._highlight = extmark
        self.parcels_by_extmark[id] = parcel

        if not self.expanded[id] then
            self.expanded[id] = {
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
