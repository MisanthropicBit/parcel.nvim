local Parcel = require("parcel.parcel")
local loader = require("parcel.loader")
local notify = require("parcel.notify")
local Path = require("parcel.path")
local sources = require("parcel.sources")
local Spec = require("parcel.spec")
local state = require("parcel.state")
local Task = require("parcel.tasks")
local tblx = require("parcel.tblx")
local utils = require("parcel.utils")

---@enum parcel.DiffState
local DiffState = {
    None = "none",
    Added = "added",
    Updated = "updated",
    Removed = "removed",
}

---@alias parcel.ParcelChanges table<parcel.DiffState, parcel.Parcel[]>

---@param parcel_changes parcel.ParcelChanges
---@return string
local function create_update_message(parcel_changes, spec_errors)
    local message = {}

    for _, diff_state in pairs(DiffState) do
        if diff_state ~= DiffState.None then
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

    if spec_errors > 0 then
        table.insert(message, ("Found %d parcel specification error(s)"):format(spec_errors))
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
    for _, parcel in ipairs(parcel_changes[DiffState.Added]) do
        local ok, err = run_config(parcel)

        if not ok then
            notify_log_error("new", parcel)
        end
    end

    -- Reload plugins and rerun configs for updated parcels
    for _, parcel in ipairs(parcel_changes[DiffState.Updated]) do
        -- loader.reload_parcel(parcel)
        local ok, err = run_config(parcel)

        if not ok then
            notify_log_error("updated", parcel)
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
            indexed[source_name][spec[1]] = spec
        end
    end

    return indexed
end

---@param source parcel.Source
---@param installed_parcel parcel.Parcel
local function uninstall_parcel(source, installed_parcel)
    source.uninstall(installed_parcel)

    state.remove_parcel(installed_parcel)

    -- Unload plugin
    loader.unload_parcel(installed_parcel)
end

---@param user_spec parcel.Spec
---@param source parcel.Source
---@param installed_parcel parcel.Parcel
---@return boolean
local function update_parcel(user_spec, source, installed_parcel)
    local spec_diff = tblx.diff(installed_parcel:spec(), user_spec)

    if vim.tbl_count(spec_diff) == 0 then
        return false
    end

    -- Spec was updated, validate it again
    local ok, errors = user_spec:validate()

    if not ok then
        return false
    end

    -- installed_parcel:set_spec(new_spec)
    source.update(installed_parcel, { spec_diff = spec_diff })

    return true
end

---@param user_spec parcel.Spec
---@param source parcel.Source
---@return boolean
---@return parcel.Parcel?
local function install_parcel(user_spec, source)
    local spec = Spec:new(user_spec, source.name())
    local ok, errors = spec:validate()

    if not ok then
        return false
    end

    local new_parcel = Parcel:new({ spec = spec })

    -- TODO: Use pcall because it might be a third-party source
    source.install(new_parcel)
    new_parcel:set_state(Parcel.State.Installed)
    state.add_parcel(new_parcel)

    return true, new_parcel
end

---@async
---@param specs table<parcel.SourceType, parcel.Spec[]>
---@return parcel.Task
local function update_parcels(specs)
    return Task.run(function()
        ---@type parcel.ParcelChanges
        local parcel_changes = {
            [DiffState.Added] = {},
            [DiffState.Updated] = {},
            [DiffState.Removed] = {},
        }
        local spec_errors = 0
        local indexed_specs = index_specs(specs)

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
                    uninstall_parcel(source, parcel)

                    table.insert(parcel_changes[DiffState.Removed], parcel)
                else
                    -- 2b. Check if parcel spec was updated and update it
                    if update_parcel(user_spec, source, parcel) then
                        table.insert(parcel_changes[DiffState.Updated], parcel)
                    end
                end
            end
        end

        -- 3. Iterate user specs and see if any parcels were added
        for source_type, spec_map in pairs(indexed_specs) do
            for name, user_spec in pairs(spec_map) do
                local source = sources.get_source(source_type)
                ---@cast source parcel.Source

                local installed_parcel = installed_parcels[source_type][name]

                if not installed_parcel then
                    -- 3a. Parcel not installed, install it
                    local ok, new_parcel = install_parcel(user_spec, source)

                    if not ok then
                        spec_errors = spec_errors + 1
                    else
                        table.insert(parcel_changes[DiffState.Added], new_parcel)
                    end
                end
            end
        end

        local message = create_update_message(parcel_changes, spec_errors)

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

        -- TODO: Add a sensible timeout
        update_task:wait()

        notify.log.task_result(update_task)
    end)
end
