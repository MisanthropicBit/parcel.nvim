local Parcel = require("parcel.parcel")
local loader = require("parcel.loader")
local notify = require("parcel.notify")
local sources = require("parcel.sources")
local Spec = require("parcel.spec")
local state = require("parcel.state")
local Task = require("parcel.tasks")
local tblx = require("parcel.tblx")

---@enum parcel.DiffState
local DiffState = {
    None = "none",
    Add = "add",
    Update = "update",
    Remove = "remove",
}

---@alias parcel.ParcelChanges table<parcel.DiffState, parcel.Parcel[]>

---@param parcel_changes parcel.ParcelChanges
local function create_update_message(parcel_changes)
    local message = {}

    for _, diff_state in ipairs(DiffState) do
        local change_count = #parcel_changes[diff_state]

        if change_count > 0 then
            table.insert(message, ("%sed %d parcel(s)"):format(diff_state, change_count))
        end
    end

    return table.concat(message, "\n")
end

--- Compute the difference between a current and new spec
---@param current_spec parcel.Spec
---@param new_spec parcel.Spec
---@return table
local function compute_spec_diff(current_spec, new_spec)
    return tblx.diff(current_spec, new_spec)
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

---@param source parcel.Source
---@param installed_parcel parcel.Parcel?
---@param user_spec parcel.Spec
---@return parcel.DiffState, boolean, parcel.Parcel?
local function resolve_spec(source, installed_parcel, user_spec)
    local change = DiffState.None
    local spec_error = false

    -- TODO: Just compute the diff and install/update/uninstall later?
    if installed_parcel then
        -- 2a. Parcel is installed, check if it was either updated or removed
        if not user_spec then
            -- 2b. Parcel was removed in the spec, uninstall it
            source.uninstall(installed_parcel)
            state.remove_parcel(installed_parcel)
            change = DiffState.Remove

            return DiffState.Remove, spec_error, installed_parcel
        else
            -- 2c. Check if parcel spec was updated and update it
            local spec_diff = compute_spec_diff(installed_parcel:spec(), user_spec)

            if vim.tbl_count(spec_diff) > 0 then
                -- Spec was updated, validate it again
                local errors = user_spec:validate()

                if #errors > 0 then
                    spec_error = true
                else
                    -- installed_parcel:set_spec(new_spec)
                    source.update(installed_parcel, { spec_diff = spec_diff })

                    return DiffState.Update, spec_error, installed_parcel
                end
            end
        end
    else
        -- 2d. Parcel not installed, install it
        local spec = Spec:new(user_spec, source.name())
        local errors = spec:validate()

        if #errors > 0 then
            spec_error = true
        else
            local new_parcel = Parcel:new({ spec = spec })

            source.install(new_parcel) -- TODO: Check that task succeeded
            state.add_parcel(new_parcel)

            return DiffState.Add, spec_error, new_parcel
        end
    end

    return change, spec_error, installed_parcel
end

---@async
---@param specs table<parcel.SourceType, table<string, parcel.Spec>>
return function(specs)
    Task.run(function()
        ---@type parcel.ParcelChanges
        local parcel_changes = {
            [DiffState.Add] = {},
            [DiffState.Update] = {},
            [DiffState.Remove] = {},
        }
        local spec_errors = 0

        -- 1. Get already installed parcels
        local installed_parcels = state.get_installed_parcels(specs)

        -- 2. Iterate through the specs and compare them to the state on disk
        for source_type, spec_map in pairs(specs) do
            for name, spec in pairs(spec_map) do
                local source = sources.get_source(source_type)
                ---@cast source parcel.Source

                local installed_parcel = installed_parcels[source_type][name]
                local change, spec_error, parcel = resolve_spec(source, installed_parcel, spec)

                if spec_error then
                    spec_errors = spec_errors + 1
                else
                    table.insert(parcel_changes[change], installed_parcel)
                end
            end
        end

        if spec_errors > 0 then
            notify.log.error("Found %d parcel specification error(s)", spec_errors)
        end

        local message = create_update_message(parcel_changes)

        if #message == 0 then
            message = "No parcel updates"
        else
            -- 3. Run configurations for new parcels
            for _, parcel in ipairs(parcel_changes[DiffState.Add]) do
                local ok, err = run_config(parcel)

                if not ok then
                    notify.log.error(
                        "Failed to run configuration for new parcel %s with source %s",
                        parcel:name(),
                        "TODO" -- parcel():source():name()
                    )
                end
            end

            -- 4. Reload plugins and rerun configs for updated parcels
            for _, parcel in ipairs(parcel_changes[DiffState.Update]) do
                loader.reload_parcel(parcel)
                local ok, err = run_config(parcel)

                if not ok then
                    notify.log.error(
                        "Failed to run configuration for updated parcel %s with source %s",
                        parcel:name(),
                        "TODO" -- parcel():source():name()
                    )
                end
            end
        end

        notify.log.info(message)
    end)
end
