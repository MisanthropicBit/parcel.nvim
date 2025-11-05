local Spinner = require("parcel.animation.spinner")
local async = require("parcel.async")
local config = require("parcel.config")
local Grid = require("parcel.ui.grid")
local Lines = require("parcel.ui.lines")
local notify = require("parcel.notify")
local sources = require("parcel.sources")
local state = require("parcel.state")
local Task = require("parcel.tasks")
local Parcel = require("parcel.parcel")
local update_checker = require("parcel.update_checker")

-- TODO:
-- * Listen to PackChanged and update overview if packages are installed/deleted

---@class parcel.OnKeyCallbackContext
---@field parcel   parcel.Parcel
---@field hl_id    integer
---@field lnum     integer
---@field col      integer

---@alias parcel.OnKeyCallback fun(overview: parcel.Overview, context: parcel.OnKeyCallbackContext)

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
---@field lines parcel.Lines

---@class parcel.OverviewOptions
---@field open boolean?
---@field float boolean? open the overview in a float if true
---@field mods string? any split modifiers such as "vertical"

---@class parcel.Overview
---@field lines parcel.Lines
---@field parcels_by_extmark table<integer, parcel.Parcel>
---@field highlights_by_parcel table<string, parcel.Highlight>
---@field selected table<integer, boolean>
---@field sections table<integer, parcel.Section>
---@field parcels parcel.Parcel[]
local Overview = {}

Overview.__index = Overview

---@return parcel.Overview
function Overview.new()
    return setmetatable({
        lines = Lines:new(),
        parcels_by_extmark = {},
        highlights_by_parcel = {},
        extmarks_by_parcel = {},
        selected = {},
        sections = {},
        parcels = {},
    }, Overview)
end

---@param options parcel.OverviewOptions?
function Overview:open(options)
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

    self:on_key(mappings.disable, function(_self, context)
        -- TODO: We could disable by:
        -- * Moving the package out of start/ or opt/
        -- * Remove from runtimepath
        --
        -- How do we disable the plugin if it is already loaded?
    end)

    -- self:on_key(mappgins.reload, ...)

    self:on_key(mappings.expand, function(_self, context)
        if context.parcel then
            _self:toggle_expand(context.parcel)
        end
    end)

    self:on_key(mappings.previous, function(_self, context)
        if not context.parcel then
            return
        end

        local prev_lnum = _self.grid:get_prev(context.lnum)

        if prev_lnum then
            vim.api.nvim_win_set_cursor(_self.win_id, { prev_lnum, 1 })
        end
    end)

    self:on_key(mappings.next, function(_self, context)
        if not context.parcel then
            return
        end

        local next_lnum = _self.grid:get_next(context.lnum)

        if next_lnum then
            vim.api.nvim_win_set_cursor(_self.win_id, { next_lnum, 1 })
        end
    end)

    self:on_key(mappings.update, function(_self, context)
        if not context.parcel or context.parcel:state() == Parcel.State.Updating then
            return
        end

        -- TODO: Common function for updating
        -- TODO: Throttle calls to render
        -- TODO: Make a utility method in this class to render a grid position

        -- 1. Create spinner animation that updates grid cell
        local spinner = Spinner.new(config.ui.icons.state.updating, function(frame)
            _self.grid:set_cell(frame, context.lnum, 1)
        end, { duration = 10000 })

        -- 2. Start animation
        spinner:start()

        -- 3. Create autocmd to listen to PackChanged with kind == 'update'
        --    name == package.name and stop the animation then
        vim.api.nvim_create_autocmd("PackChanged", {
            group = nil, -- TODO:
            once = true,
            ---@param event { data: PackEventData }
            callback = function(event)
                if event.data.kind == "update" and event.data.spec.name == context.parcel:name() then
                    spinner:stop()
                    context.parcel:set_state(context.parcel:active() and Parcel.State.Active or Parcel.State.Inactive)
                    local hl = self.highlights_by_parcel[context.parcel:name()]
                    _self.grid:render_col(hl.id, config.ui.icons.state.active, 1)
                end
            end,
        })

        -- 4. Run vim.pack.update
        vim.pack.update({ context.parcel:name() })
    end)

    self:on_key(mappings.update_all, function(_self, context)
        local parcels = state.parcels({ Parcel.State.Updating })
        local parcel_count = vim.tbl_count(parcels)

        -- 1. Create spinner animation that updates all grid cells
        local spinner = Spinner.new(config.ui.icons.state.updating, function(frame)
            for name, parcel in pairs(parcels) do
                _self.grid:set_cell(frame, context.lnum, 1)
            end
        end, { duration = 10000 })

        -- 2. Start animation
        spinner:start()

        -- 3. Create autocmd to listen to PackageChanged with kind == 'update'
        --    name == package.name and remove cell from animation. Stop
        --    animation when all packages have been updated
        vim.api.nvim_create_autocmd("PackChanged", {
            group = nil, -- TODO:
            ---@param event { data: PackEventData }
            callback = function(event)
                local name = event.data.spec.name
                local updated_parcel = parcels[name]

                if event.data.kind == "update" and updated_parcel then
                    parcels[name] = nil
                    parcel_count = parcel_count - 1

                    if parcel_count == 0 then
                        spinner:stop()
                    end
                end
            end,
        })

        -- 4. Run vim.pack.update
        local names = vim.tbl_map(function(parcel)
            return parcel:name()
        end, parcels)

        vim.pack.update(names)
    end)

    self:on_key(mappings.collapse_all, function(_self, context)
        if context.parcel then
            return
        end

        for highlight_id, section in pairs(self.sections) do
            local highlight = self.highlights_by_parcel[context.parcel:name()]
            local lnum = highlight.lnum

            if section.visible then
                section.lines:clear(self.buffer, lnum + 1)
                section.visible = false
            end
        end
    end)

    -- TODO: Should throttle render instead
    -- Make sure that we do not call update too often
    -- self.set_contents = async.utils.throttle(100, self.set_contents)

    -- Set an autocommand to fire on renders
    vim.api.nvim_create_autocmd("User", {
        pattern = "ParcelRender",
        callback = function()
        end,
    })

    if config.check_for_updates then
        update_checker.check(state.parcels())
    end
end

---@return boolean
function Overview:visible()
    return vim.api.nvim_buf_is_valid(self.buffer) and vim.api.nvim_win_is_valid(self.win_id)
end

---@param type string
---@param parcel parcel.Parcel
function Overview:notify_change(type, parcel)
    if not self:visible() then
        return
    end

    if type == "state" then
        -- TODO: Update parcel row
    end
end

---@param parcel parcel.Parcel
function Overview:toggle_expand(parcel)
    local highlight = self.highlights_by_parcel[parcel:name()]
    local lnum = highlight.lnum
    local section = self.sections[highlight.id]

    section.visible = not section.visible
    local method = section.visible and "render" or "clear"

    section.lines[method](section.lines, self.buffer, lnum + 1)

    -- Set cursor position to the toggled parcel's row
    vim.api.nvim_win_set_cursor(self.win_id, { lnum, 0 })
end

---@param parcel parcel.Parcel
---@return table[]
function Overview:create_parcel_columns(parcel)
    local highlights = config.ui.highlights
    local _icons = config.ui.icons
    local source_type_icon = _icons.sources.git

    return {
        -- { _icons.state[parcel:active()], rpad = 2, hl = highlights[parcel:active()] },
        { _icons.state.active, rpad = 2,             hl = highlights.installed },
        { _icons.parcel,       rpad = 2,             hl = highlights.parcel },
        -- { source_type_icon, rpad = 1, hl = highlights.source },
        { parcel:name(),       align = "left",       pad = "auto",             min_pad = 1, hl = "String" },
        { parcel:version(),    rpad = 1,             hl = highlights.version },
        { parcel:pinned(),     icon = _icons.pinned, hl = highlights.pinned,   rpad = 1 },
    }
end

---@param lnum integer
function Overview:set_parcel_row(lnum)
    local _, parcel = self:get_parcel_at_cursor(lnum)

    if not parcel then
        return
    end

    self.grid:row(lnum):set_columns(self:create_parcel_columns(parcel))
end

---@param parcel parcel.Parcel
---@param section parcel.Lines
---@return parcel.Lines
function Overview:add_source_section(parcel, section)
    local _icons = config.ui.icons
    local section_bullet = _icons.section_bullet
    local source = parcel:source()

    source.write_section(parcel, section)

    return section
end

---@param parcel parcel.Parcel
---@param lines parcel.Lines
---@return parcel.Lines
function Overview:add_failed_subsection(parcel, lines)
    local errors = parcel:errors()

    lines:add("%d error(s) encountered", "ErrorMsg", { args = { #errors } }):newlines(2)

    for idx, err in ipairs(errors) do
        local is_process_error = err.context.err and err.context.err.code

        lines:add(err.message, "ErrorMsg"):newline()

        if is_process_error then
            -- TODO: What to do about newlines in process output?
            lines
                :add("Process exited with code %d and error message", "WarningMsg", { args = { err.context.err.code } })
                :newline()

            for _, err_line in ipairs(err.context.err.stderr) do
                lines:add(err_line, nil):newline()
            end
        end
    end

    return lines
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

    local parcel_state = parcel:state()

    -- TODO: Use grid for proper alignment
    section
        :newline()
        :add("Name       ", "Keyword", { sep = section_bullet })
        :add(parcel:name())
        :newline()
        :add("Revision   ", "Keyword", { sep = section_bullet })
        :add(parcel:revision())
        :newline()
        :add("Source     ", "Keyword", { sep = section_bullet })
        :add(_icons.sources[parcel:source()] .. " " .. parcel:source_url())
        :newline()
        :add("Path       ", "Keyword", { sep = section_bullet })
        :add(parcel:path())
        :newline()

    -- self:add_source_section(parcel, section):newline()

    return section
end

---@param lnum integer
---@return integer?, parcel.Parcel?
function Overview:get_parcel_at_cursor(lnum)
    local highlight = self.grid:get_nearest(lnum)

    if not highlight then
        return nil, nil
    end

    return highlight.id, self.parcels_by_extmark[highlight.id]
end

---@param key string
---@param callback parcel.OnKeyCallback
function Overview:on_key(key, callback)
    local wrapped = function()
        local lnum = vim.fn.line(".")
        local hl_id, parcel = self:get_parcel_at_cursor(lnum)
        ---@cast hl_id -nil
        ---@cast parcel -nil

        callback(self, {
            parcel = parcel,
            hl_id = hl_id,
            lnum = lnum,
            col = vim.fn.col("."),
        })
    end

    vim.keymap.set("n", key, wrapped, { buffer = self.buffer })
end

---@private
function Overview:set_extmarks()
    if not self.grid then
        return
    end

    local parcels = state.parcels()

    -- After each render, map extmarks for each parcel so we can easily
    -- find the nearest parcel under the cursor
    for idx, highlight in ipairs(self.grid:get_line_highlights()) do
        local parcel = parcels[idx]
        local id = highlight.id

        self.parcels_by_extmark[id] = parcel
        self.highlights_by_parcel[parcel:name()] = highlight

        if not self.sections[id] then
            self.sections[id] = {
                visible = false,
                lines = self:add_subsection(parcel, self.parcel_row_offset + idx - 1),
            }
        end
    end
end

---@private
function Overview:render()
    local parcels = state.parcels()

    self.lines
        :add(("Packages (%d)"):format(#parcels), "Title")
        :newlines(2)
        :add("Press g? for help.", "Comment")
        :newlines(2)

    self.parcel_row_offset = self.lines:row_count()

    if vim.tbl_count(parcels) == 0 then
        self.lines:add("No packages installed")
        return
    end

    -- TODO: Rename to Table
    self.grid = Grid.new({
        buffer = self.buffer,
        lnum = self.parcel_row_offset,
    })

    for idx = 1, #parcels do
        self.grid:add_row(self:create_parcel_columns(parcels[idx]))
    end

    self.lines:add(self.grid)
    self.lines:render(self.buffer)

    self:set_extmarks()
end

---@param options parcel.OverviewOptions?
---@return parcel.Overview
function Overview.main(options)
    if not main_overview then
        main_overview = Overview.new()
    end

    if options and options.open then
        main_overview:open(options)
        main_overview:render()
    end

    return main_overview
end

return Overview
