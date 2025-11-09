local config = {}

local Path = require("parcel.path")

local config_loaded = false

---@class parcel.UiConfig
---@field icons table
---@field mappings table
---@field float table

---@class parcel.Config
---@field ui parcel.UiConfig

local default_config = {
    log_level = vim.log.levels.WARN,
    update_timeout_ms = 10000,
    ui = {
        animated = true,
        animation_update = 100,
        columns = {
            "state",
            "pinned",
            "package_icon",
            "name",
            "version",
            "revision",
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
                updating = {'⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'},
            },
            sources = {
                git = "󰊢",
            },
        },
        highlights = {
            installed = "diffAdded",
            not_installed = "ErrorMsg",
            updating = "WarningMsg",
            updates_available = "",
            failed = "ErrorMsg",
            loaded = "diffAdded",
            parcel = "Special",
            pinned = "Identifier",
            dev = "Identifier",
            source = "Special",
            version = "Type",
        },
        mappings = {
            collapse_all = "c",
            delete = "x",
            -- disable = "d",
            expand = "o",
            help = "g?",
            log = "L",
            next = "J",
            previous = "K",
            update = "u",
            update_all = "U",
            update_force = "f",
            update_force_all = "F",
        },
        float = {
            padding = 0,
            border = "rounded",
            mappings = {},
            options = {},
        },
    },
}

-- TODO: Handle absence of nerdfonts
local non_configurable_options = {
    ui = {
        icons = {
            dash = "─",
            section_sep = "│",
            section_bullet = "├",
        }
    }
}

--- Validate a dimension
local function validate_dimension(arg)
    return arg == "auto" or type(arg) == "number"
end

--- Validate a floating window border
local function validate_border(arg)
    local presets = {
        "none",
        "single",
        "double",
        "rounded",
        "solid",
        "shadow",
    }

    return presets[arg] ~= nil or type(arg) == "table"
end

--- Validate a config
---@param _config parcel.Config
local function validate_config(_config)
    vim.validate({
        ["float.padding"] = { _config.ui.float.padding, "number" },
        ["float.border"] = { _config.ui.float.border, validate_border, "valid border" },
        ["float.mappings"] = { _config.ui.float.mappings, "table" },
        ["float.mappings.close"] = { _config.ui.float.mappings.close, "string" },
        ["float.mappings.apply"] = { _config.ui.float.mappings.apply, "string" },
        ["float.mappings.jsonpp"] = { _config.ui.float.mappings.jsonpp, "string" },
        ["float.mappings.help"] = { _config.ui.float.mappings.help, "string" },
        ["float.title"] = { _config.ui.float.title, "boolean" },
        ["float.title_pos"] = { _config.ui.float.title_pos, "string" },
        ["float.autoclose"] = { _config.ui.float.autoclose, "boolean" },
        ["float.enter"] = { _config.ui.float.enter, "boolean" },
        ["float.options"] = { _config.ui.float.options, "table" },
    })
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
    user_config = vim.tbl_deep_extend("force", user_config, non_configurable_options)

    -- TODO: Move to constants or somewhere else
    user_config.path = Path.join(vim.fn.stdpath("data"), "parcel")
    user_config.namespace = vim.api.nvim_create_namespace("parcel")

    -- TODO: Merge with vim.g.parcel

    -- Private fields
    user_config._parcels = {}

    -- validate_config(_user_config)

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
