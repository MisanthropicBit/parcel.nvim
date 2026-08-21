local constants = require("parcel.constants")
local config = require("parcel.config")
local diagnostics = require("parcel.diagnostics")
local fs = require("parcel.fs")
local ui = require("parcel.ui")
local notify = require("parcel.notify")
local sources = require("parcel.sources")
local state = require("parcel.state")
local Parcel = require("parcel.parcel")
local Path = require("parcel.path")
local update_checker = require("parcel.update_checker")
local utils = require("parcel.utils")
local highlight = require("parcel.highlight")
local Task = require("parcel.tasks.task")
local git = require("parcel.async.git")

-- TODO: Lookup column indices via column names

---@class parcel.OnKeyCallbackContext
---@field parcel  parcel.Parcel
---@field row_pos parcel.ui.RowPos
---@field col     integer

---@alias parcel.OnKeyCallback fun(overview: parcel.Overview, context: parcel.OnKeyCallbackContext)

---@type table<parcel.State, string>
local hl_by_state = {
    [Parcel.State.Active] = "ParcelActive",
    [Parcel.State.Inactive] = "ParcelInactive",
    [Parcel.State.Updating] = "ParcelUpdating",
    [Parcel.State.UpdatesAvailable] = "ParcelUpdatesAvailable",
    [Parcel.State.Failed] = "ParcelFailed",
}

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
    buflisted = true,
    modifiable = false,
    filetype = "parcel-overview",
}

---@return integer?, integer?
local function find_existing_overview()
    local overview_win_id
    local overview_buffer

    for _, win_id in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win_id) then
            local buffer = vim.api.nvim_win_get_buf(win_id)

            if vim.bo[buffer].filetype == "parcel-overview" then
                overview_win_id = win_id
                overview_buffer = buffer
                break
            end
        end
    end

    if not overview_buffer then
        for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buffer) and vim.bo[buffer].filetype == "parcel-overview" then
                overview_buffer = buffer
            end
        end
    end

    return overview_win_id, overview_buffer
end

---@type parcel.Overview?
local main_overview = nil

---@class parcel.Section
---@field visible boolean
---@field lines parcel.ui.Lines
---@field grid parcel.ui.Grid

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
    local buffer

    if self:is_valid() then
        -- 1. If the current overview is still valid, focus it
        self:focus()
    elseif self:hidden() then
        -- 2. Window is not valid but buffer is valid (hidden) so open that buffer in a new window
        self:open_window(_options, self.buffer, nil)
    else
        -- 3. Try to find an existing overview
        local existing_win_id, existing_buffer = find_existing_overview()

        if existing_win_id and existing_buffer then
            -- If found, focus that
            self.win_id = existing_win_id
            self.buffer = existing_buffer

            self:focus()
        else
            self:open_window(_options, nil, nil)
        end
    end

    if not self.lines then
        self.lines = ui.Lines.new({ buffer = self.buffer })
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

    if config.update_checker.enable then
        update_checker.listen(function(parcels)
            self:set_update_available_diagnostics(parcels)
        end)

        update_checker.start()

        -- TODO: Any other events we should listen to?
        vim.api.nvim_create_autocmd("WinClosed", {
            pattern = tostring(self.win_id),
            group = constants.augroup,
            once = true,
            callback = update_checker.stop,
        })
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

function Overview:open_window(options, buffer, win_id)
    if buffer then
        self.buffer = buffer
    else
        self.buffer = vim.api.nvim_create_buf(false, true)
    end

    if options.float then
        self.win_id = ui.float.open_centered(self.buffer)
    else
        vim.cmd((options.mods or "") .. " new")

        self.buffer = vim.api.nvim_win_get_buf(0)
        self.win_id = vim.api.nvim_get_current_win()
    end

    -- If we did not have a buffer, it is now created so set the current
    -- window's buffer to it
    if not buffer then
        vim.api.nvim_set_current_buf(self.buffer)
    end
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
        _self:clear_selected()
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

    self:on_key(mappings.open_split, function(_self, context)
        _self:open_handler("split", context.parcel)
    end)

    self:on_key(mappings.open_vertical, function(_self, context)
        _self:open_handler("vertical split", context.parcel)
    end)

    self:on_key(mappings.open_tab, function(_self, context)
        _self:open_handler("tabedit", context.parcel)
    end)

    self:on_key(mappings.open_edit, function(_self, context)
        _self:open_handler("edit", context.parcel)
    end)

    self:on_key(mappings.open_float, function(_self, context)
        _self:open_handler("float", context.parcel)
    end)

    self:on_key(mappings.log, function(_self, context)
        -- git log --pretty="format:%h %<|(60,trunc)%s (%cr)" --abbrev-commit --decorate --date=short --color=never --no-show-signature

        Task.run_with_logging(function()
            local ok, result = git.log(context.parcel:path(), {
                args = {
                    '--pretty="format:%h %<|(60,trunc)%s (%cr)"',
                    "--abbrev-commit",
                    "--decorate",
                    "--date=short",
                    "--color=never",
                    "--no-show-signature",
                },
            })

            if not ok then
                error(result)
            end

            -- 1. Open a new buffer with log output

            -- 2. Highlight results (might be better with a regex-based highlight than extmarks)

            -- 3. Set keymaps (gs, gv, gt, etc.). Pressing on any line opens up the commit and
            -- change. Also add a visual mode where the same is shown for the selected lines
        end)
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
                _self:clear_selected()

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

---@param win_cmd "split" | "vertical split" | "tabedit" | "edit" | "float"
---@param parcel parcel.Parcel
function Overview:open_handler(win_cmd, parcel)
    local row_pos = self.grid:get_row_or_previous(vim.fn.line("."))

    if not row_pos then
        return
    end

    local section = self.sections[row_pos.row_id]
    local data = section.grid:element_at(self.buffer,vim.fn.line(".") - 1, vim.fn.col(".") - 1)

    if not data or not data.type or not data.value then
        notify.warn("Found no element to open at cursor")
        return
    end

    local _type, value = data.type, data.value
    vim.print(vim.inspect({ _type, value }))

    if parcel:source().handle_open(parcel, value, _type) then
        return
    end

    -- TODO: Cannot navigate back to overview after "edit"

    if _type == "path" or _type == "docs" or _type == "license" then
        if win_cmd ~= "float" then
            vim.cmd(("%s %s"):format(win_cmd, value))
        end

        -- TODO: Open float
    elseif _type == "help" then
        if win_cmd == "edit" then
            vim.cmd(("help %s | only"):format(vim.fs.basename(value)))
        else
            local no_split_win_cmd = win_cmd:gsub("split", ""):gsub("edit", "")

            vim.cmd(("%s help %s"):format(no_split_win_cmd, vim.fs.basename(value)))
        end
    end
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
    self:clear_selected()

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
    if not self.buffer or not self.win_id then
        return false
    end

    return vim.api.nvim_buf_is_valid(self.buffer) and not vim.api.nvim_win_is_valid(self.win_id)
end

---@return boolean
function Overview:is_valid()
    if not self.buffer or not self.win_id then
        return false
    end

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

---@private
---@param parcels parcel.Parcel[]
function Overview:set_update_available_diagnostics(parcels)
    if not self:visible() then
        return
    end

    local parcel_diagnostics = vim.tbl_map(function(parcel)
        local row_id = self.parcel_to_row_id[parcel:name()]
        local row, _ = self.grid:get_row_id_pos(row_id)

        vim.print(vim.inspect({ row_id, row, parcel:name() }))

        return diagnostics.create(row_id, {
            col = 0,
            lnum = row,
            message = config.ui.icons.state.updateable .. " update available",
            bufnr = self.buffer,
            severity = vim.diagnostic.severity.WARN,
        })
    end, parcels)

    diagnostics.set(self.buffer, parcel_diagnostics)
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

function Overview:clear_selected()
    vim.api.nvim_buf_clear_namespace(self.buffer, constants.select_hl_namespace, 0, -1)
end

---@param parcel parcel.Parcel
---@return parcel.ui.CellOptions[]
function Overview:create_parcel_cells(parcel)
    local cell_options = {}
    local columns = config.ui.columns
    local _icons = config.ui.icons

    for _, column in ipairs(columns) do
        if column == ui.ColumnType.State then
            table.insert(
                cell_options,
                { ui.Text.new({ _icons.state[parcel:state()], hl = hl_by_state[parcel:state()] }) }
            )
        elseif column == ui.ColumnType.PackageIcon then
            table.insert(cell_options, { ui.Text.new({ _icons.parcel, hl = "ParcelIcon" }) })
        elseif column == ui.ColumnType.Name then
            table.insert(cell_options, { ui.Text.new({ parcel:name(), hl = "ParcelName" }) })
        elseif column == ui.ColumnType.VersionRevision then
            local version = parcel:version()
            local pinned = parcel:pinned() and _icons.pinned or ""

            if type(version) == "string" and utils.git.is_sha(version) then
                version = version:sub(1, 7) .. " " .. _icons.pinned
            end

            -- local label_fg, label_bg = highlight.create_for_label("ParcelLabel")

            local version_label = ui.Text.label({
                buffer = self.buffer,
                -- hl = { fg = label_fg, bg = label_bg },
                hl = {
                    fg = "#ffffff",
                    bg = "#1398ab",
                },
                text = version and utils.version.format(version) or "No version",
            })

            table.insert(cell_options, { version_label })
        end
    end

    return cell_options
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

---@private
---@param title string
---@param values string[]
---@param data unknown[]?
---@return parcel.ui.CellOptions
function Overview:create_section(title, values, data)
    local title_text = { ui.Text.new({ title, hl = "ParcelSectionKey", data = data and { type = title:lower(), value = data[1] } or nil }) }
    local texts = {}

    for idx, value in ipairs(values) do
        local _data = data and { type = title:lower(), value = data[idx] } or nil

        table.insert(texts, { value, data = _data })
    end

    return { title_text, { ui.Text.delimited(texts, { " | ", hl = "ParcelSectionKey" }) } }
end

---@param parcel parcel.Parcel
---@return parcel.ui.Lines, parcel.ui.Grid
function Overview:add_subsection(parcel, offset)
    -- TODO: Let the source (only git for now) render the subsection
    local _icons = config.ui.icons
    -- local section_bullet = _icons.bullet

    local section = ui.Lines.new({
        buffer = self.buffer,
        row = offset,
        col = 2,
    })

    local parcel_state = parcel:state()
    local path = parcel:path()
    local grid = ui.Grid.new({ buffer = self.buffer })
    local source_url = parcel:source_url() -- _icons.sources[parcel:source()] .. " " .. parcel:source_url()

    -- TODO: Extend so we can add separate highlights for section_bullet and "Name"
    -- TODO: Shorten version if git sha
    grid:add_row(self:create_section("Name", { parcel:name() }))
        :add_row(self:create_section("Version", { tostring(parcel:version() or "-") }, { tostring(parcel:version() or "-") } ))
        :add_row(self:create_section("Revision", { parcel:revision() }, { parcel:revision() }))
        :add_row(self:create_section("Source", { source_url }, { source_url }))
        :add_row(self:create_section("Path", { path }))

    local doc_paths = fs.find_docs(path)
    local help_paths = fs.find_help_files(path)
    local license_paths = fs.find_licenses(path)

    local function clean_paths(paths)
        if #paths == 0 then
            return { "-" }
        end

        return vim.tbl_map(vim.fs.basename, paths)
    end

    local cleaned_doc_paths = clean_paths(doc_paths)
    local cleaned_help_paths = clean_paths(help_paths)
    local cleaned_license_paths = clean_paths(license_paths)

    -- TODO: Add branch (git source)
    -- TODO: Add commit (git source)
    grid:add_row(self:create_section("Docs", cleaned_doc_paths, doc_paths))
        :add_row(self:create_section("Help", cleaned_help_paths, help_paths))
        :add_row(self:create_section("License", cleaned_license_paths, license_paths))

    -- vim.print(vim.inspect(grid._rows[#grid._rows - 1]))

    section:newline():add(grid):newline()

    return section, grid
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

    for idx, parcel in ipairs(parcels) do
        local row_id = self.grid:row_ids()[idx]

        self.row_id_to_parcel[row_id] = parcel
        self.parcel_to_row_id[parcel:name()] = row_id

        local lines, grid = self:add_subsection(parcel, self.parcel_row_offset + idx + 1)

        if not self.sections[row_id] then
            self.sections[row_id] = {
                visible = false,
                lines = lines,
                grid = grid,
            }
        end
    end

    vim.print(vim.inspect(self.parcel_to_row_id))

    for _, eid in pairs(self.parcel_to_row_id) do
        vim.print(vim.inspect({ eid, vim.api.nvim_buf_get_extmark_by_id(self.buffer, constants.extmark_namespace, eid, {}) }))
    end

    -- After each render, map extmarks for each parcel so we can easily
    -- find the nearest parcel under the cursor
    -- for idx, row_id in ipairs(self.grid:row_ids()) do
    --     local parcel = parcels[idx]
    --
    --     self.row_id_to_parcel[row_id] = parcel
    --     self.parcel_to_row_id[parcel:name()] = row_id
    --
    --     local lines, grid = self:add_subsection(parcel, self.parcel_row_offset + idx + 1)
    --
    --     if not self.sections[row_id] then
    --         self.sections[row_id] = {
    --             visible = false,
    --             lines = lines,
    --             grid = grid,
    --         }
    --     end
    -- end
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
        :add(ui.Text.new({ ("Packages (%d)"):format(#parcels), hl = "ParcelTitle" }))
        :newline()
        :add(ui.Text.new({ "Press g? for help.", hl = "ParcelHelpText" }))
        :newline()

    self.parcel_row_offset = self.lines:size()

    if #parcels == 0 then
        self.lines:add("No packages installed")
    else
        self.grid = ui.Grid.new({
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
