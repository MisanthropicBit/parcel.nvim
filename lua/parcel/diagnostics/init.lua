local diagnostics = {}

local config = require("parcel.config")

local ns_id = vim.api.nvim_create_namespace("parcel.diagnostics")

function diagnostics.namespace_id()
    return ns_id
end

function diagnostics.setup()
    local sign_config = {
        text = {
            [2] = config.ui.icons.state.updateable,
        },
        numhl = {
            [2] = "DiagnosticSignWarn",
        },
        linehl = {},
    }

    vim.diagnostic.config({
        signs = false,
        underline = false,
        virtual_text = {
            source = false,
            prefix = "",
            spacing = 0,
        },
    }, ns_id)
end

---@param ext_id integer
---@param diagnostic vim.Diagnostic
---@return vim.Diagnostic
function diagnostics.create(ext_id, diagnostic)
    return vim.tbl_extend("force", diagnostic, {
        source = "parcel.nvim",
        namespace = ns_id,
        user_data = { ext_id = ext_id }
    })
end

---@param buffer integer
---@param _diagnostics vim.Diagnostic[]
---@param options vim.diagnostic.Opts?
function diagnostics.set(buffer, _diagnostics, options)
    vim.diagnostic.set(ns_id, buffer, _diagnostics, options)
end

-- TODO: Update diagnostics when parcels are sorted
function diagnostics.update()
end

return diagnostics
