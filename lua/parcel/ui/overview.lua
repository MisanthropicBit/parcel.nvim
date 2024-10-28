-- local actions = require("parcel.actions")
local async_utils = require("parcel.tasks.async_utils")
local compat = require("parcel.compat")
local config = require("parcel.config")
local Grid = require("parcel.ui.grid")
local icons = require("parcel.icons")
local Lines = require("parcel.ui.lines")
local notify = require("parcel.notify")
local sources = require("parcel.sources")
local state = require("parcel.state")
local Task = require("parcel.tasks")

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

---@type parcel.Overview?
local main_overview = nil

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

---@return parcel.Overview
function Overview:new()
    return setmetatable({
        lines = Lines:new(),
        parcels_by_extmark = {},
        selected = {},
        sections = {},
        parcels = {},
        timer = nil,
    }, Overview)
end

---@param options parcel.OverviewOptions?
function Overview:init(options)
    local _options = options or {}

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
        vim.api.nvim_set_option_value(option, value, { scope = "local", win = self.win_id })
    end

    -- Set default buffer options
    for option, value in pairs(buffer_options) do
        vim.api.nvim_set_option_value(option, value, { buf = self.buffer })
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

    self:on_key(mappings.update, function(_, parcel, row_idx)
        if parcel then
            self:update_parcels({ parcel })
        end
    end)

    self:on_key(mappings.update_all, function()
        if #self.parcels > 0 then
            self:update_parcels(self.parcels)
        end
    end)

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

    -- self.grid = Grid:new({
    --     buffer = self.buffer,
    --     lnum = self.parcel_row_offset,
    -- })
end

function Overview:notify(type, parcel)
    -- TODO: Return if not visible

    if not self.timer then
        self.timer = compat.loop.new_timer()
    end
end

---@async
---@param parcels parcel.Parcel[]
function Overview:update_parcels(parcels)
    Task.run(function()
        local tasks = {}

        for _, parcel in ipairs(parcels) do
            local source = sources.get_source(parcel:source_name())
            ---@cast source -nil

            table.insert(tasks, Task.new(function()
                source.update(parcel)
            end))
        end

        local ok, results = Task.wait_all(tasks, {
            concurrency = config.concurrency,
            timeout = 20000
        })

        if not ok then
            if results == Task.timeout then
                notify.log.error(
                    "Update of %d parcel(s) timed out after %d milliseconds",
                    #parcels,
                    20000
                )
            else
                local failed_updates = 0

                for _, result in ipairs(results) do
                    if not result.ok then
                        failed_updates = failed_updates + 1
                    end
                end

                if failed_updates > 0 then
                    notify.log.error("%d parcel(s) failed to update", failed_updates)
                end
            end
        end
    end)
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
    local source_type_icon = _icons.sources[parcel:source_name()] or _icons.sources.unknown_source

    return {
        {
            _icons.state[parcel:state()],
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
        -- {
        --     parcel:dev(),
        --     icon = _icons.dev,
        --     hl = highlights.dev,
        -- },
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

    self.parcels = state.parcels()
    self.lines
        :add("Parcels", "Title")
        :add((" (%d)"):format(#self.parcels), "Title"):newlines(2)
        :add("Press g? for help.", "Comment"):newlines(2)
    self.parcel_row_offset = self.lines:row_count()

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

---@param parcel parcel.Parcel
---@param section parcel.Lines
---@return parcel.Lines
function Overview:add_source_section(parcel, section)
    local _icons = config.ui.icons
    local section_bullet = _icons.section_bullet
    local source = sources.get_source(parcel:source_name())

    ---@cast source -nil

    local ok, result = pcall(source.write_section, parcel, section)

    if not ok then
        section
            :add("Failed to write section for source:", "Title")
            :newlines(2)
            :add(result)
    end

    return section
end

---@param parcel parcel.Parcel
---@param section parcel.Lines
---@return parcel.Lines
function Overview:add_failed_subsection(parcel, section)
    local errors = parcel:errors()

    section
        :add("%d error(s) encountered", "ErrorMsg", { args = { #errors } })
        :newlines(2)

    for idx, err in ipairs(errors) do
        local is_process_error = err.context.err and err.context.err.code

        section:add(err.message, "ErrorMsg"):newline()

        if is_process_error then
            -- TODO: What to do about newlines in process output?
            section
                :add("Process exited with code %d and error message", "WarningMsg", { args = { err.context.err.code } })
                :newline()

            for _, err_line in ipairs(err.context.err.stderr) do
                section:add(err_line, nil):newline()
            end
        end
    end

    return section
end

---@param parcel parcel.Parcel
---@return parcel.Lines
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

    section:newline()

    local parcel_state = parcel:state()

    if parcel_state == parcel.State.Failed then
        self:add_failed_subsection(parcel, section)
    elseif parcel_state == parcel.State.Updating then
        section:add("Parcel is currently updating")
    elseif parcel_state == parcel.State.NotInstalled then
        section:add("Parcel is currently disabled")
    elseif parcel_state == parcel.State.Installed then
        -- TODO: Use grid for proper alignment
        section
            :add("Name   ", "Keyword", { sep = section_bullet })
            :add(parcel:name()):newline()
            :add("Source ", "Keyword", { sep = section_bullet })
            :add(parcel:source_name()):newline()

        if parcel:source_name() ~= sources.Source.dev then
            section
                :add("Path   ", "Keyword", { sep = section_bullet })
                :add(parcel:path())
        end

        self:add_source_section(parcel, section)

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

        if deps and #deps > 0 then
            section:newlines(2)

            for _, dep in ipairs(deps) do
                section:add("%s %s", "Normal", { args = { _icons.parcel, dep.name } })
            end
        end

        section:newline()
    end

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

---@param options parcel.OverviewOptions?
---@return parcel.Overview
function Overview.main(options)
    if not main_overview then
        main_overview = Overview:new()

        main_overview:init(options)
        main_overview:update()
    end

    return main_overview
end

return Overview
