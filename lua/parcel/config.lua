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
                updating = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
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
            update = "u",
            update_all = "U",
            update_force = "f",
            update_force_all = "F",
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
        },
    },
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
function config.validate(_config)
    -- vim.validate({
    --     ["float.padding"] = { _config.ui.float.padding, "number" },
    -- })
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
    user_config = vim.tbl_deep_extend("force", default_config, _user_config or {}, non_configurable_options)

    -- config.validate(_user_config)

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
