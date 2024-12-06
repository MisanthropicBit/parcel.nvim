local config = require("parcel.config")
local constants = require("parcel.constants")
local loader = require("parcel.loader")
local notify = require("parcel.notify")
local Parcel = require("parcel.parcel")
local Path = require("parcel.path")
local sources = require("parcel.sources")
local Spec = require("parcel.spec")
local state = require("parcel.state")
local Task = require("parcel.tasks")
local tblx = require("parcel.tblx")
local ui = require("parcel.ui")
local utils = require("parcel.utils")

---@enum parcel.ParcelChange
local ParcelChange = {
    None = "none",
    Added = "added",
    Updated = "updated",
    Removed = "removed",
}

---@alias parcel.ParcelChanges table<parcel.ParcelChange, parcel.Parcel[]>

---@param parcel_changes parcel.ParcelChanges
---@param errors integer
---@param spec_errors integer
---@return string
local function create_update_message(parcel_changes, errors, spec_errors)
    local message = {}

    for _, diff_state in pairs(ParcelChange) do
        if diff_state ~= ParcelChange.None then
            local change_count = #parcel_changes[diff_state]

            if change_count > 0 then
                table.insert(
                    message,
                    ("%s %d parcel(s)"):format(
                        utils.str.titlecase(diff_state),
                        change_count
                    )
                )
            end
        end
    end

    if errors > 0 then
        table.insert(message, ("%d parcel error(s)"):format(errors))
    end

    if spec_errors > 0 then
        table.insert(message, ("%d parcel specification error(s)"):format(spec_errors))
    end

    return table.concat(message, Path.newline)
end

--- Run a configuration for a parcel
---@param parcel parcel.Parcel
local function run_config(parcel)
    if #parcel:errors() > 0 then
        return
    end

    local config_spec = parcel:spec():get("config")

    if config_spec then
        local config_func

        if type(config_spec) == "string" then
            local module = config_spec

            ---@diagnostic disable-next-line: unused-function
            config_func = function()
                require(module)
            end
        else
            config_func = config_spec
        end

        return pcall(config_func)
    end
end

---@param parcel_changes parcel.ParcelChanges
local function run_configs(parcel_changes)
    local function notify_log_error(parcel_type, parcel)
        notify.log.error(
            "Failed to run configuration for %s parcel %s for source %s",
            parcel_type,
            parcel:name(),
            parcel:source_name()
        )
    end

    -- Run configurations for new parcels
    for _, parcel in ipairs(parcel_changes[ParcelChange.Added]) do
        if not parcel:state() == parcel.State.Failed then
            local ok, err = run_config(parcel)

            if not ok then
                notify_log_error("new", parcel)
            end
        end
    end

    -- Reload plugins and rerun configs for updated parcels
    for _, parcel in ipairs(parcel_changes[ParcelChange.Updated]) do
        if not parcel:state() == parcel.State.Failed then
            -- loader.reload_parcel(parcel)
            local ok, err = run_config(parcel)

            if not ok then
                notify_log_error("updated", parcel)
            end
        end
    end
end

---@param spec_sources table<parcel.SourceType, parcel.Spec[]>
---@return table<parcel.SourceType, table<string, parcel.Spec>>
local function index_specs(spec_sources)
    local indexed = {}

    for source, _ in pairs(sources.Source) do
        indexed[source] = {}
    end

    for source_name, specs in pairs(spec_sources) do
        for _, spec in ipairs(specs) do
            local spec_name = type(spec) == "string" and spec or spec[1]

            indexed[source_name][spec_name] = spec
        end
    end

    return indexed
end

---@async
---@param specs table<parcel.SourceType, parcel.Spec[]>
---@return parcel.Task
local function update_parcels(specs)
    return Task.run(function()
        ---@type parcel.ParcelChanges
        local parcel_changes = {
            [ParcelChange.Added] = {},
            [ParcelChange.Updated] = {},
            [ParcelChange.Removed] = {},
        }
        local errors, spec_errors = 0, 0
        local indexed_specs = index_specs(specs)
        local actions = require("parcel.actions")
        local tasks = {}

        -- 1. Get already installed parcels
        local installed_parcels = state.get_installed_parcels(specs)

        -- 2. Iterate installed parcels and see if any parcels were removed
        for source_type, parcels in pairs(installed_parcels) do
            for _, parcel in ipairs(parcels) do
                local user_spec = indexed_specs[source_type][parcel:name()]
                local source = sources.get_source(source_type)
                ---@cast source parcel.Source

                if not user_spec then
                    -- 2a. Parcel was removed in the spec, uninstall it
                    table.insert(tasks, Task.new(function()
                        local ok = actions.uninstall.uninstall_parcel(source, parcel)

                        if not ok then
                            errors = errors + 1
                        end

                        -- ui.Overview.main():notify()

                        table.insert(parcel_changes[ParcelChange.Removed], parcel)
                    end))
                else
                    -- 2b. Check if parcel spec was updated and update it
                    table.insert(tasks, Task.new(function()
                        if actions.update.update_parcel(user_spec, source, parcel) then
                            table.insert(parcel_changes[ParcelChange.Updated], parcel)
                        else
                            errors = errors + 1
                        end
                    end))
                end

                Task.wait_scheduler()
            end
        end

        -- 3. Iterate user specs and see if any parcels were added
        for source_type, spec_map in pairs(indexed_specs) do
            for name, user_spec in pairs(spec_map) do
                local source = sources.get_source(source_type)
                ---@cast source parcel.Source

                local parcel_installed = installed_parcels[source_type][name]

                if parcel_installed then
                    local spec = Spec:new(user_spec, source.name())
                    local parcel = Parcel:new({ spec = spec })

                    parcel:set_state(Parcel.State.Installed)
                    state.add_parcel(parcel)
                else
                    -- 3a. Parcel not installed, install it
                    table.insert(tasks, Task.new(function()
                        local spec_ok, install_ok, new_parcel = actions.install.install_parcel(user_spec, source)

                        if not spec_ok or not install_ok then
                            errors = errors + (install_ok and 0 or 1)
                            spec_errors = spec_errors + (spec_ok and 0 or 1)
                        else
                            table.insert(parcel_changes[ParcelChange.Added], new_parcel)
                        end
                    end))
                end

                Task.wait_scheduler()
            end
        end

        Task.wait_all(tasks, { concurrency = config.concurrency })

        local message = create_update_message(parcel_changes, errors, spec_errors)

        if #message == 0 then
            if not vim.g.parcel_loaded then
                notify.log.info("No parcel updates")
            end
        else
            -- 4. Run configurations for new and updated parcels
            run_configs(parcel_changes)

            notify.log.info(message)
        end
    end)
end

---@async
---@param specs table<parcel.SourceType, parcel.Spec[]>
return function(specs)
    Task.run(function()
        local update_task = update_parcels(specs)

        update_task:wait(constants.default_multi_task_timeout)
        notify.log.task_result(update_task)
    end)
end
