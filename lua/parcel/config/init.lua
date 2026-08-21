local config = {}

local config_loaded = false

---@class parcel.UiConfig
---@field icons table
---@field mappings table
---@field float table

---@class parcel.Config
---@field ui parcel.UiConfig

-- TODO: Handle absence of nerdfonts
local default_config = {
    log_level = vim.log.levels.WARN,
    concurrency = 4,
    update_checker = {
        enable = true,
        concurrency = 4,
        interval_ms = 1 * 60 * 60 * 1000,
        timeout_ms = 10000,
    },
    ui = {
        animated = true,
        animation_update = 100,
        columns = {
            "state",
            "package_icon",
            "name",
            "version_revision",
        },
        icons = {
            parcel = "",
            pinned = "󰐃",
            bullet = "●",
            version = { left = "", right = "" },
            state = {
                active = "",
                inactive = "",
                failed = "",
                updateable = "",
                updating = {
                    "⠋",
                    "⠙",
                    "⠹",
                    "⠸",
                    "⠼",
                    "⠴",
                    "⠦",
                    "⠧",
                    "⠇",
                    "⠏",
                },
            },
            sources = {
                git = "󰊢",
            },
        },
        mappings = {
            collapse_all = "c",
            delete = "x",
            -- disable = "d",
            toggle_select = "s",
            clear_selects = "S",
            expand = "o",
            help = "g?",
            log = "L",
            next = "J",
            previous = "K",
            info = "i",
            update = "u",
            update_all = "U",
            update_force = "f",
            update_force_all = "F",
            open_split = "gs",
            open_vertical = "gv",
            open_tab = "gt",
            open_edit = "ge",
            open_float = "gf",
            open_url = "gu",
        },
    },
}

---@param object table<string, unknown>
---@param schema table<string, unknown>
---@return table
local function validate_schema(object, schema)
    local errors = {}

    for key, value in pairs(schema) do
        if type(value) == "string" then
            local ok, err = pcall(vim.validate, { [key] = { object[key], value } })

            if not ok then
                table.insert(errors, err)
            end
        elseif type(value) == "table" then
            if type(object) ~= "table" then
                table.insert(errors, "Expected a table at key " .. key)
            else
                if vim.is_callable(value[1]) then
                    local ok, err = pcall(vim.validate, {
                        [key] = { object[key], value[1], value[2] },
                    })

                    if not ok then
                        table.insert(errors, err)
                    end
                else
                    vim.list_extend(errors, validate_schema(object[key], value))
                end
            end
        end
    end

    return errors
end

--- Validate a config
---@param _config parcel.Config
function config.validate(_config)
    local validators = require("lua.parcel.config.config_validators")
    local ui = require("parcel.ui")

    -- stylua: ignore start
    local config_schema = {
        log_level = validators.table_value_validator(vim.log.levels),
        concurrency = validators.is_positive_non_zero_number_validator,
        update_checker = {
            enable = "boolean",
            concurency = validators.is_positive_non_zero_number_validator,
            interval_ms = validators.is_positive_non_zero_number_validator,
            timeout_ms = validators.is_positive_non_zero_number_validator,
        },
        ui = {
            animated = "boolean",
            animation_update = validators.is_positive_non_zero_number_validator,
            columns = validators.table_value_validator(ui.ColumnType),
            icons = {
                parcel = "string",
                pinned = "string",
                bullet = "string",
                state = {
                    active = "string",
                    inactive = "string",
                    failed = "string",
                    updating = "string",
                },
                sources = {
                    git = "string",
                },
            },
            mappings = {
                collapse_all = "string",
                delete = "string",
                -- disable = "string",
                toggle_select = "string",
                clear_selects = "string",
                expand = "string",
                help = "string",
                log = "string",
                next = "string",
                previous = "string",
                info = "string",
                update = "string",
                update_all = "string",
                update_force = "string",
                update_force_all = "string",
                open_split = "string",
                open_vertical = "string",
                open_tab = "string",
                open_edit = "string",
                open_float = "string",
                open_url = "string",
            }
        },
    }
    -- stylua: ignore end

    local errors = validate_schema(_config, config_schema)

    return #errors == 0, errors
end

---@type parcel.Config
local user_config = default_config

-- Used in testing
---@private
function config._default_config()
    return default_config
end

---@param _user_config? parcel.Config
function config.setup(_user_config)
    user_config = vim.tbl_deep_extend("force", default_config, _user_config or {})

    config.validate(user_config)

    config_loaded = true
end

setmetatable(config, {
    __index = function(_, key)
        -- Lazily load configuration so there is no need to call setup explicitly
        if not config_loaded then
            config.setup()
        end

        return user_config[key]
    end,
})

return config
