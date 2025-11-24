local constants = require("parcel.constants")
local config = require("parcel.config")
local diagnostics = require("parcel.diagnostics")
local Grid = require("parcel.ui.grid")
local Lines = require("parcel.ui.lines")
local Text = require("parcel.ui.text")
local notify = require("parcel.notify")
local sources = require("parcel.sources")
local state = require("parcel.state")
local Parcel = require("parcel.parcel")
local Path = require("parcel.path")
local update_checker = require("parcel.update_checker")
local utils = require("parcel.utils")

-- TODO: Lookup column indices via column names
-- TODO: Allow marking packages for bulk operations
-- TODO: Use ui.Label for versions

---@class parcel.OnKeyCallbackContext
---@field parcel   parcel.Parcel
---@field row_pos  parcel.ui.RowPos
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
---@field lines parcel.ui.Lines

---@class parcel.OverviewOptions
---@field float boolean? open the overview in a float if true
---@field mods string? any split modifiers such as "vertical"

---@class parcel.Overview
---@field lines parcel.ui.Lines
---@field row_id_to_parcel table<integer, parcel.Parcel>
---@field parcel_to_row_id table<string, parcel.ui.RowId>
---@field selected table<integer, integer>
---@field sections table<parcel.ui.RowId, parcel.Section>
local Overview = {}

Overview.__index = Overview

---@return parcel.Overview
function Overview.new()
    return setmetatable({
        row_id_to_parcel = {},
        parcel_to_row_id = {},
        selected = {},
        sections = {},
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

    if not self.lines then
        self.lines = Lines.new({ buffer = self.buffer })
    end

    self.lines:clear()

    -- Set default window options
    for option, value in pairs(window_options) do
        vim.api.nvim_set_option_value(option, value, { scope = "local", win = self.win_id })
    end

    -- Set default buffer options
    for option, value in pairs(buffer_options) do
        vim.api.nvim_set_option_value(option, value, { buf = self.buffer })
    end

    if config.check_for_updates then
        -- TODO: When window is hidden, stop update_checker
        update_checker.start()
    end

    -- Listen to state change events and re-render the ui if necessary
    state.listen(function(data)
        if data.kind == "update" then
            return
        end

        if data.kind == "delete" then
            local row_id = self.parcel_to_row_id[data.spec.name]
            local section = self.sections[row_id]

            if section.visible then
                self:toggle_expand(row_id)
            end
        end

        self:render()
    end)

    vim.api.nvim_win_set_hl_ns(self.win_id, constants.hl_namespace)

    self:set_keymaps()
end

---@private
function Overview:set_keymaps()
    local mappings = config.ui.mappings

    -- self:on_key(mappings.disable, function(_self, context)
    -- TODO: We could disable by:
    -- * Moving the package out of start/ or opt/
    -- * Remove from runtimepath
    --
    -- How do we disable the plugin if it is already loaded?
    -- end)

    -- self:on_key(mappgins.reload, ...)

    self:on_key(mappings.toggle_select, function(_self, context)
        if not context.parcel then
            return
        end

        local row_id = context.row_pos.row_id

        _self:toggle_select(row_id, context.row_pos.row)
    end)

    self:on_key(mappings.clear_selects, function(_self, context)
        vim.api.nvim_buf_clear_namespace(_self.buffer, constants.select_hl_namespace, 0, -1)
    end)

    self:on_key(mappings.previous, function(_self, context)
        if not context.parcel then
            return
        end

        local result = _self.grid:get_prev(context.row_pos.row)

        if result then
            vim.api.nvim_win_set_cursor(_self.win_id, { result.row, 1 })
        end
    end)

    self:on_key(mappings.next, function(_self, context)
        if not context.parcel then
            return
        end

        local result = _self.grid:get_next(context.row_pos.row)

        if result then
            vim.api.nvim_win_set_cursor(_self.win_id, { result.row, 1 })
        end
    end)

    self:on_key(mappings.update, function(_self, context)
        local parcel = context.parcel

        if not parcel or parcel:state() == Parcel.State.Updating then
            notify.info("Parcel is already updating")
            return
        end

        _self:update_parcels({ [parcel:name()] = parcel }, context)
    end)

    self:on_key(mappings.update_all, function(_self, context)
        _self:update_parcels(state.parcels({ exclude_states = { Parcel.State.Updating } }), context)
    end)

    self:on_key(mappings.update_force, function(_self, context)
        local parcel = context.parcel

        if not parcel or parcel:state() == Parcel.State.Updating then
            notify.info("Parcel is already updating")
            return
        end

        _self:update_parcels({ parcel:name() }, context, true)
    end)

    self:on_key(mappings.update_force_all, function(_self, context)
        _self:update_parcels(state.parcels({ exclude_states = { Parcel.State.Updating } }), context, true)
    end)

    self:on_key(mappings.delete, function(_self, context)
        if not context.parcel then
            return
        end

        local parcels = self:get_selected_parcels(context)
        local prompt = #parcels > 1 and ("Delete %d parcels?"):format(#parcels)
            or ("Delete parcel %s?"):format(parcels[1]:name())

        vim.ui.input({
            prompt = prompt,
            completion = function()
                -- TODO:
            end,
        }, function(input)
            if input and input:lower() == "yes" then
                vim.pack.del(vim.tbl_map(function(parcel)
                    return parcel:name()
                end, parcels))
            end
        end)
    end)

    self:on_key(mappings.expand, function(_self, context)
        local row_pos = _self.grid:get_row_or_previous(vim.fn.line("."))

        if not row_pos then
            return
        end

        _self:toggle_expand(row_pos.row_id, row_pos.row)
    end)

    self:on_key(mappings.collapse_all, function(_self, context)
        if context.parcel then
            return
        end

        for row_id, section in pairs(self.sections) do
            if section.visible then
                section.lines:clear()
                section.visible = false
            end
        end
    end)
end

---@private
---@param context parcel.OnKeyCallbackContext
---@return parcel.Parcel[]
function Overview:get_selected_parcels(context)
    local any_selected = false
    local selected = {}

    for row_id, extmark_id in pairs(self.selected) do
        if extmark_id then
            local parcel = self.row_id_to_parcel[row_id]
            table.insert(selected, parcel)
            any_selected = true
        end
    end

    if any_selected then
        return selected
    end

    return { context.parcel }
end

---@param parcels table<string, parcel.Parcel>
---@param context parcel.OnKeyCallbackContext
---@param force boolean?
function Overview:update_parcels(parcels, context, force)
    -- TODO: Throttle calls to render for spinner
    -- TODO: Make a utility method in this class to render a grid position
    -- TODO: What happens if the PackChanged evnet never fires or on errors?
    -- PackChanged does not fire if there are no updates so we need a new
    -- event or a timeout.
    vim.pack.update(vim.tbl_keys(parcels), { force = force })
end

---@return boolean
function Overview:visible()
    return self.buffer
        and vim.api.nvim_buf_is_valid(self.buffer)
        and self.win_id
        and vim.api.nvim_win_is_valid(self.win_id)
end

---@return boolean
function Overview:hidden()
    return vim.api.nvim_buf_is_valid(self.buffer) and not vim.api.nvim_win_is_valid(self.win_id)
end

---@return boolean
function Overview:is_valid()
    return vim.api.nvim_buf_is_valid(self.buffer) and vim.api.nvim_win_is_valid(self.win_id)
end

---@return boolean
function Overview:focus()
    if not self:visible() or not self:is_valid() then
        return false
    end

    vim.api.nvim_set_current_win(self.win_id)

    return true
end

---@param notification parcel.StateChangeNotifcation
function Overview:notify_change(notification)
    if not self:visible() then
        return
    end

    ---@diagnostic disable-next-line: empty-block
    if notification.type == "state" then
        -- TODO:
        -- local row_id = self.parcel_to_row_id[notification.name]
        -- self.grid:set_cell(notification.state, row_id, 1)
    elseif notification.type == "update_available" then
        local parcel_diagnostics = vim.tbl_map(function(parcel)
            return diagnostics.create(0, {
                col = 0,
                lnum = 0,
                message = config.icons.state.updateable .. " update available",
                bufnr = self.buffer,
                severity = vim.diagnostic.severity.WARN,
            })
        end, notification.parcels)

        diagnostics.set(self.buffer, parcel_diagnostics)
    end
end

---@param row_id parcel.ui.RowId
---@param row integer?
function Overview:toggle_expand(row_id, row)
    local section = self.sections[row_id]

    if section.visible then
        section.lines:clear({ row, 0 })
    else
        section.lines:render({ row, 0 })
    end

    section.visible = not section.visible

    if row then
        -- Set cursor position to the toggled parcel's row
        vim.api.nvim_win_set_cursor(self.win_id, { row, 0 })
    end
end

---@param row_id parcel.ui.RowId
---@param row integer
function Overview:toggle_select(row_id, row)
    local extmark_id = self.selected[row_id]

    if extmark_id then
        vim.api.nvim_buf_del_extmark(self.buffer, constants.select_hl_namespace, extmark_id)
        self.selected[row_id] = nil
    else
        -- Create a background extmark on top of entire row
        self.selected[row_id] = vim.api.nvim_buf_set_extmark(self.buffer, constants.select_hl_namespace, row - 1, 0, {
            end_row = row - 1,
            end_col = vim.fn.col("$") - 1,
            hl_group = "Search", -- TODO: Generate background color from highlight
        })
    end
end

---@param parcel parcel.Parcel
---@return parcel.ui.CellOptions[]
function Overview:create_parcel_cells(parcel)
    local highlights = config.ui.highlights
    local _icons = config.ui.icons
    local source_type_icon = _icons.sources.git
    local version = parcel:version()
    local pinned = parcel:pinned() and _icons.pinned or ""

    if type(version) == "string" and utils.git.is_sha(version) then
        version = version:sub(1, 7) .. " " .. _icons.pinned
    end

    local version_label = Text.label({
        buffer = self.buffer,
        hl = {
            fg = "#ffffff",
            bg = "#1398ab",
        },
        text = version and utils.version.format(version) or "No version",
    })

    return {
        { Text.new({ _icons.state[parcel:state()], hl = highlights[parcel:state()] }) },
        { Text.new({ _icons.parcel, hl = highlights.parcel }) },
        { Text.new({ parcel:name(), hl = "String" }) },
        { version_label },
    }
end

---@param parcel parcel.Parcel
---@param section parcel.ui.Lines
---@return parcel.ui.Lines
function Overview:add_source_section(parcel, section)
    local _icons = config.ui.icons
    local section_bullet = _icons.section_bullet
    local source = parcel:source()

    source.write_section(parcel, section)

    return section
end

-- ---@param parcel parcel.Parcel
-- ---@param lines parcel.Lines
-- ---@return parcel.Lines
-- function Overview:add_failed_subsection(parcel, lines)
--     local errors = parcel:errors()
--
--     lines:add({ ("%d error(s) encountered"):format(#errors), hl = "ErrorMsg" }):newlines(2)
--
--     for idx, err in ipairs(errors) do
--         local is_process_error = err.context.err and err.context.err.code
--
--         lines:add({ err.message, hl = "ErrorMsg" }):newline()
--
--         if is_process_error then
--             -- TODO: What to do about newlines in process output?
--             lines
--                 :add({
--                     ("Process exited with code %d and error message"):format(err.context.err.code),
--                     hl = "WarningMsg",
--                 })
--                 :newline()
--
--             for _, err_line in ipairs(err.context.err.stderr) do
--                 lines:add(err_line):newline()
--             end
--         end
--     end
--
--     return lines
-- end

---@param parcel parcel.Parcel
---@return parcel.ui.Lines
function Overview:add_subsection(parcel, offset)
    -- TODO: Let the source (only git for now) render the subsection
    local _icons = config.ui.icons
    local section_bullet = _icons.bullet
    local section_double_bullet = _icons.section_sep .. _icons.dash

    local section = Lines.new({
        buffer = self.buffer,
        row = offset,
        col = 2,
    })

    local parcel_state = parcel:state()
    local grid = Grid.new({ buffer = self.buffer })

    -- TODO: Extend so we can add separate highlights for section_bullet and "Name"
    grid:add_row({ { Text.new({ "Name", hl = "Keyword" }) }, { parcel:name() } })
        :add_row({ { Text.new({ "Version", hl = "Keyword" }) }, { tostring(parcel:version()) } })
        :add_row({ { Text.new({ "Revision", hl = "Keyword" }) }, { parcel:revision() } })
        :add_row({
            { Text.new({ "Source", hl = "Keyword" }) },
            { _icons.sources[parcel:source()] .. " " .. parcel:source_url() },
        })
        :add_row({ { Text.new({ "Path", hl = "Keyword" }) }, { parcel:path() } })

    local readme_path

    for _, readme in ipairs({ "README.md", "README.rst" }) do
        readme_path = Path.join(parcel:path(), readme)
        local readme_stat = vim.uv.fs_stat(readme_path)

        if readme_stat then
            break
        end
    end

    if readme_path then
        grid:add_row({ { Text.new({ "README", hl = "Keyword" }) }, { readme_path } })
    end

    section:newline():add(grid):newline()

    return section
end

---@private
---@param key string
---@param callback parcel.OnKeyCallback
function Overview:on_key(key, callback)
    local wrapped = function()
        local row_pos = self.grid:get_row_or_previous(vim.fn.line("."))

        callback(self, {
            parcel = self.row_id_to_parcel[row_pos.row_id],
            row_pos = row_pos,
            col = vim.fn.col("."),
        })
    end

    vim.keymap.set("n", key, wrapped, { buffer = self.buffer })
end

---@private
---@param parcels parcel.Parcel[]
function Overview:set_row_ids(parcels)
    if #parcels == 0 then
        return
    end

    -- After each render, map extmarks for each parcel so we can easily
    -- find the nearest parcel under the cursor
    for idx, row_id in ipairs(self.grid:row_ids()) do
        local parcel = parcels[idx]

        self.row_id_to_parcel[row_id] = parcel
        self.parcel_to_row_id[parcel:name()] = row_id

        if not self.sections[row_id] then
            self.sections[row_id] = {
                visible = false,
                lines = self:add_subsection(parcel, self.parcel_row_offset + idx + 1),
            }
        end
    end
end

---@private
function Overview:render()
    if not self:visible() then
        return
    end

    local parcels = state.parcel_list()

    self.lines:clear()
    self.lines:clear_contents()

    -- TODO: Add active/inactive counts
    self.lines
        :add(Text.new({ ("Packages (%d)"):format(#parcels), hl = "Title" }))
        :newline()
        :add(Text.new({ "Press g? for help.", hl = "Comment" }))
        :newline()

    self.parcel_row_offset = self.lines:size()

    if #parcels == 0 then
        self.lines:add("No packages installed")
    else
        self.grid = Grid.new({
            buffer = self.buffer,
            row = self.parcel_row_offset,
        })

        for idx = 1, #parcels do
            self.grid:add_row(self:create_parcel_cells(parcels[idx]))
        end

        self.lines:add(self.grid)
    end

    self.lines:render(nil, true)

    self:set_row_ids(parcels)
end

---@return parcel.Overview
function Overview.main()
    if not main_overview then
        main_overview = Overview.new()
    end

    return main_overview
end

return Overview
